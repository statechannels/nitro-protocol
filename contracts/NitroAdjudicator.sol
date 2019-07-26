pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Commitment.sol";
import "./Rules.sol";
import "./Outcome.sol";

contract IAssetHolder {
    function setOutcome(address channel, Outcome.allocation[] memory outcome) public;
    function clearOutcome(address channel) public;
}

contract NitroAdjudicator {
    using Commitment for Commitment.CommitmentStruct;
    using SafeMath for uint256;

    // TODO: Challenge duration should depend on the channel
    uint256 constant CHALLENGE_DURATION = 5 minutes;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

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

    mapping(address => Commitment.CommitmentStruct) challenges; // store challengeCommitments here
    // TODO also securely store challenger (so that refutation commitments can be required to have the same signer as the challenger )

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
        require(
            moveAuthorized(agreedCommitment, signatures[0]),
            "ForceMove: agreedCommitment not authorized"
        );
        require(
            moveAuthorized(challengeCommitment, signatures[1]),
            "ForceMove: challengeCommitment not authorized"
        );
        require(
            Rules.validTransition(agreedCommitment, challengeCommitment),
            "ForceMove: Invalid transition"
        );

        address channelId = agreedCommitment.channelId();
        challenges[channelId] = challengeCommitment;
        _registerOutcome(channelId, challengeCommitment.outcome, now + CHALLENGE_DURATION);
        emit ChallengeCreated(channelId, challengeCommitment, now + CHALLENGE_DURATION);
    }

    function refute(
        Commitment.CommitmentStruct memory refutationCommitment,
        Signature memory signature
    ) public {
        address channel = refutationCommitment.channelId();

        require(
            moveAuthorized(refutationCommitment, signature),
            "Refute: move must be authorized"
        );

        require(
            Rules.validRefute(
                challenges[channel],
                refutationCommitment,
                signature.v,
                signature.r,
                signature.s
            ),
            "Refute: must be a valid refute"
        );

        emit Refuted(channel, refutationCommitment);
        _clearOutcome(channel, challenges[channel].outcome);
        challenges[channel] = 0;
    }

    function respond(
        Commitment.CommitmentStruct memory responseCommitment,
        Signature memory signature
    ) public {
        address channel = responseCommitment.channelId();

        require(
            moveAuthorized(responseCommitment, signature),
            "RespondWithMove: move must be authorized"
        );

        require(
            Rules.validRespondWithMove(
                challenges[channel],
                responseCommitment,
                signature.v,
                signature.r,
                signature.s
            ),
            "RespondWithMove: must be a valid response"
        );

        emit Responded(channel, responseCommitment, signature.v, signature.r, signature.s);
        _clearOutcome(channel, challenges[channel].outcome);
        challenges[channel] = 0;
    }

    function respondFromAlternative(
        Commitment.CommitmentStruct memory _alternativeCommitment,
        Commitment.CommitmentStruct memory _responseCommitment,
        Signature memory _alternativeSignature,
        Signature memory _responseSignature
    ) public {
        address channel = _responseCommitment.channelId();

        require(
            moveAuthorized(_responseCommitment, _responseSignature),
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
                challenges[channel],
                _alternativeCommitment,
                _responseCommitment,
                v,
                r,
                s
            ),
            "RespondWithMove: must be a valid response"
        );

        emit RespondedFromAlternative(_responseCommitment);
        _clearOutcome(channel, challenges[channel].outcome);
        challenges[channel] = 0;
    }

    function _registerOutcome(
        address channel,
        Outcome.SingleAssetOutcome[] memory outcome,
        uint256 finalizedAt
    ) internal {
        // loop over all AssetHolders and register the SingleAssetOutcomeWithMetaData on each
        for (uint256 i = 0; i < outcome.length; i++) {
            IAssetHolder AssetHolder = IAssetHolder(channel, outcome[i].assetHolder);
            Outcome.SingleAssetOutcomeWithMetaData memory singleAssetOutcomeWithMetaData = Outcome.SingleAssetOutcomeWithMetaData(
                outcome[i],
                finalizedAt
            );
            AssetHolder.setOutcome(channel, singleAssetOutcomeWithMetaData);
        }
    }

    function _clearOutcome(address channel, Outcome.SingleAssetOutcome[] memory outcome) internal {
        // loop over all AssetHolders and register the SingleAssetOutcomeWithMetaData on each
        for (uint256 i = 0; i < outcome.length; i++) {
            IAssetHolder AssetHolder = IAssetHolder(channel, outcome[i].assetHolder);
            AssetHolder.clearOutcome(channel);
        }
    }
    // ************************
    // ForceMove Protocol Logic
    // ************************

    function _conclude(ConclusionProof memory proof) internal {
        address channelId = proof.penultimateCommitment.channelId();
        _registerOutcome(channelId, proof.ultimateCommitment.outcome);
        emit Concluded(channelId);
    }

    function moveAuthorized(
        Commitment.CommitmentStruct memory _commitment,
        Signature memory signature
    ) public pure returns (bool) {
        return
            _commitment.mover() ==
                Commitment.recoverSigner(abi.encode(_commitment), signature.v, signature.r, signature.s);
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
