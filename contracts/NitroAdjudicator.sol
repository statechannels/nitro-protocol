pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Commitment.sol";
import "./Rules.sol";

contract NitroAdjudicator {
    using Commitment for Commitment.CommitmentStruct;
    using SafeMath for uint256;

    // TODO: Challenge duration should depend on the channel
    uint256 constant CHALLENGE_DURATION = 5 minutes;

    struct Authorization {
        // Prevents replay attacks:
        // It's required that the participant signs the message, meaning only
        // the participant can authorize a withdrawal.
        // Moreover, the participant should sign the address that they wish
        // to send the transaction from, preventing any replay attack.
        address participant; // the account used to sign commitment transitions
        address destination; // either an account or a channel
        uint256 amount;
        address sender; // the account used to sign transactions
    }

    struct ConclusionProof {
        Commitment.CommitmentStruct penultimateCommitment;
        Signature penultimateSignature;
        Commitment.CommitmentStruct ultimateCommitment;
        Signature ultimateSignature;
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
        Signature[] memory signatures
    ) public {
        require(!isChannelClosed(agreedCommitment.channelId()), "ForceMove: channel must be open");
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

        outcomes[channelId] = Outcome(
            challengeCommitment.participants,
            now + CHALLENGE_DURATION,
            challengeCommitment,
            challengeCommitment.allocation,
            challengeCommitment.token
        );

        emit ChallengeCreated(channelId, challengeCommitment, now + CHALLENGE_DURATION);
    }

    function refute(
        Commitment.CommitmentStruct memory refutationCommitment,
        Signature memory signature
    ) public {
        address channel = refutationCommitment.channelId();
        require(!isChannelClosed(channel), "Refute: channel must be open");

        require(
            Library.moveAuthorized(refutationCommitment, signature),
            "Refute: move must be authorized"
        );

        require(
            Rules.validRefute(
                outcomes[channel].challengeCommitment,
                refutationCommitment,
                signature.v,
                signature.r,
                signature.s
            ),
            "Refute: must be a valid refute"
        );

        emit Refuted(channel, refutationCommitment);
        Outcome memory updatedOutcome = Outcome(
            outcomes[channel].destination,
            0,
            refutationCommitment,
            refutationCommitment.allocation,
            refutationCommitment.token
        );
        outcomes[channel] = updatedOutcome;
    }

    function respond(
        Commitment.CommitmentStruct memory responseCommitment,
        Signature memory signature
    ) public {
        address channel = responseCommitment.channelId();
        require(!isChannelClosed(channel), "RespondWithMove: channel must be open");

        require(
            Library.moveAuthorized(responseCommitment, signature),
            "RespondWithMove: move must be authorized"
        );

        require(
            Rules.validRespondWithMove(
                outcomes[channel].challengeCommitment,
                responseCommitment,
                signature.v,
                signature.r,
                signature.s
            ),
            "RespondWithMove: must be a valid response"
        );

        emit Responded(channel, responseCommitment, signature.v, signature.r, signature.s);

        Outcome memory updatedOutcome = Outcome(
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
        Signature memory _alternativeSignature,
        Signature memory _responseSignature
    ) public {
        address channel = _responseCommitment.channelId();
        require(!isChannelClosed(channel), "AlternativeRespondWithMove: channel must be open");

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

        Outcome memory updatedOutcome = Outcome(
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

        outcomes[channelId] = Outcome(
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

    function moveAuthorized(
        Commitment.CommitmentStruct memory _commitment,
        Signature memory signature
    ) public pure returns (bool) {
        return
            _commitment.mover() ==
                recoverSigner(abi.encode(_commitment), signature.v, signature.r, signature.s);
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
    event Responded(
        address channelId,
        Commitment.CommitmentStruct response,
        uint8 v,
        bytes32 r,
        bytes32 ss
    );
    event RespondedFromAlternative(Commitment.CommitmentStruct alternativeResponse);
}
