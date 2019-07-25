pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Commitment.sol";
import "./Rules.sol";

contract INitroLibrary { traction of the NitroLibrary contract

    struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
    }

    function recoverSigner(bytes calldata _d, uint8 _v, bytes32 _r, bytes32 _s) external pure returns(address);

    function affords(
        address recipient,
        Outcome calldata outcome,
        uint funding
    ) external pure returns (uint256);

    function reprioritize(
        Outcome calldata allocation,
        Outcome calldata guarantee
    ) external pure returns (Outcome memory);

    function moveAuthorized(Commitment.CommitmentStruct calldata _commitment, Signature calldata signature) external pure returns (bool);

        function reduce(
        Outcome memory outcome,
        address recipient,
        uint amount,
        address token
    ) public pure returns (Outcome memory);
}

contract NitroAdjudicator {
    using Commitment for Commitment.CommitmentStruct;
    using SafeMath for uint;
    INitroLibrary Library; 

    constructor(address _NitroLibraryAddress) public {
        Library = INitroLibrary(_NitroLibraryAddress); 
    }

    // TODO: Challenge duration should depend on the channel
    uint constant CHALLENGE_DURATION = 5 minutes;

    struct Authorization {
        // Prevents replay attacks:
        // It's required that the participant signs the message, meaning only
        // the participant can authorize a withdrawal.
        // Moreover, the participant should sign the address that they wish
        // to send the transaction from, preventing any replay attack.
        address participant; // the account used to sign commitment transitions
        address destination; // either an account or a channel
        uint amount;
        address sender; // the account used to sign transactions
    }

    struct ConclusionProof {
        Commitment.CommitmentStruct penultimateCommitment;
        INitroLibrary.Signature penultimateSignature; 
        Commitment.CommitmentStruct ultimateCommitment;
        INitroLibrary.Signature ultimateSignature; 
    }

 
    // **********************
    // ForceMove Protocol API
    // **********************

    function conclude(ConclusionProof memory proof) public {
        _conclude(proof);
    }

    function challenge(
        Commitment.CommitmentStruct memory agreedCommitment,
        Commitment.CommitmentStruct memory challengeCommitment,
        INitroLibrary.Signature[] memory signatures 
    ) public {
        require(
            !isChannelClosed(agreedCommitment.channelId()),
            "ForceMove: channel must be open"
        );
        require(
            Library.moveAuthorized(agreedCommitment, signatures[0]),
            "ForceMove: agreedCommitment not authorized"
        );
        require(
            Library.moveAuthorized(challengeCommitment, signatures[1]),
            "ForceMove: challengeCommitment not authorized"
        );
        require(
            Rules.validTransition(agreedCommitment, challengeCommitment),
            "ForceMove: Invalid transition"
        );

        address channelId = agreedCommitment.channelId();

        outcomes[channelId] = INitroLibrary.Outcome( 
            challengeCommitment.participants,
            now + CHALLENGE_DURATION,
            challengeCommitment,
            challengeCommitment.allocation,
            challengeCommitment.token
        );

        emit ChallengeCreated(
            channelId,
            challengeCommitment,
            now + CHALLENGE_DURATION
        );
    }

    function refute(Commitment.CommitmentStruct memory refutationCommitment, INitroLibrary.Signature memory signature) public { 
        address channel = refutationCommitment.channelId();
        require(
            !isChannelClosed(channel),
            "Refute: channel must be open"
        );

        require(
            Library.moveAuthorized(refutationCommitment, signature),
            "Refute: move must be authorized"
        );

        require(
            Rules.validRefute(outcomes[channel].challengeCommitment, refutationCommitment, signature.v, signature.r, signature.s),
            "Refute: must be a valid refute"
        );

        emit Refuted(channel, refutationCommitment);
        INitroLibrary.Outcome memory updatedOutcome = INitroLibrary.Outcome( 
            outcomes[channel].destination,
            0,
            refutationCommitment,
            refutationCommitment.allocation,
            refutationCommitment.token
        );
        outcomes[channel] = updatedOutcome;
    }

    function respond(Commitment.CommitmentStruct memory responseCommitment, INitroLibrary.Signature memory signature) public { 
        address channel = responseCommitment.channelId();
        require(
            !isChannelClosed(channel),
            "RespondWithMove: channel must be open"
        );

        require(
            Library.moveAuthorized(responseCommitment, signature),
            "RespondWithMove: move must be authorized"
        );

        require(
            Rules.validRespondWithMove(outcomes[channel].challengeCommitment, responseCommitment, signature.v, signature.r, signature.s),
            "RespondWithMove: must be a valid response"
        );

        emit Responded(channel, responseCommitment, signature.v, signature.r, signature.s);

        INitroLibrary.Outcome memory updatedOutcome = INitroLibrary.Outcome( 
            outcomes[channel].destination,
            0,
            responseCommitment,
            responseCommitment.allocation,
            responseCommitment.token
        );
        outcomes[channel] = updatedOutcome;
    }

    function respondFromAlternative(
        Commitment.CommitmentStruct memory _alternativeCommitment,
        Commitment.CommitmentStruct memory _responseCommitment,
        INitroLibrary.Signature memory _alternativeSignature, 
        INitroLibrary.Signature memory _responseSignature 
    )
      public
    {
        address channel = _responseCommitment.channelId();
        require(
            !isChannelClosed(channel),
            "AlternativeRespondWithMove: channel must be open"
        );

        require(
            Library.moveAuthorized(_responseCommitment, _responseSignature),
            "AlternativeRespondWithMove: move must be authorized"
        );

        uint8[] memory v = new uint8[](2);
        v[0] = _alternativeSignature.v;
        v[1] = _responseSignature.v;

        bytes32[] memory r = new bytes32[](2);
        r[0] = _alternativeSignature.r;
        r[1] = _responseSignature.r;

        bytes32[] memory s = new bytes32[](2);
        s[0] = _alternativeSignature.s;
        s[1] = _responseSignature.s;


        require(
            Rules.validAlternativeRespondWithMove(
                outcomes[channel].challengeCommitment,
                _alternativeCommitment,
                _responseCommitment,
                v,
                r,
                s
            ),
            "RespondWithMove: must be a valid response"
        );

        emit RespondedFromAlternative(_responseCommitment);

        INitroLibrary.Outcome memory updatedOutcome = INitroLibrary.Outcome( 
            outcomes[channel].destination,
            0,
            _responseCommitment,
            _responseCommitment.allocation,
            _responseCommitment.token
        );
        outcomes[channel] = updatedOutcome;
    }

    // ************************
    // ForceMove Protocol Logic
    // ************************

    function _conclude(ConclusionProof memory proof) internal {
        address channelId = proof.penultimateCommitment.channelId();
        require(
            (outcomes[channelId].finalizedAt > now || outcomes[channelId].finalizedAt == 0),
            "Conclude: channel must not be finalized"
        );

        outcomes[channelId] = INitroLibrary.Outcome( 
            proof.penultimateCommitment.destination,
            now,
            proof.penultimateCommitment,
            proof.penultimateCommitment.allocation,
            proof.penultimateCommitment.token
        );
        emit Concluded(channelId);
    }

    function isChannelClosed(address channel) internal view returns (bool) {
        return outcomes[channel].finalizedAt < now && outcomes[channel].finalizedAt > 0;
    }

    // ****************
    // Events
    // ****************
    event Deposited(address destination, uint256 amountDeposited, uint256 destinationHoldings);

    event ChallengeCreated(
        address channelId,
        Commitment.CommitmentStruct commitment,
        uint256 finalizedAt
    );
    event Concluded(address channelId);
    event Refuted(address channelId, Commitment.CommitmentStruct refutation);
    event Responded(address channelId, Commitment.CommitmentStruct response, uint8 v, bytes32 r, bytes32 ss);
    event RespondedFromAlternative(Commitment.CommitmentStruct alternativeResponse);
}