pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

import "./Commitment.sol";
import "./ConsensusCommitment.sol";

contract ConsensusApp {
    using ConsensusCommitment for ConsensusCommitment.ConsensusCommitmentStruct;

    function validTransition(
        Commitment.CommitmentStruct memory _old,
        Commitment.CommitmentStruct memory _new
    ) public pure returns (bool) {
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment = ConsensusCommitment
            .fromFrameworkCommitment(_old);
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment = ConsensusCommitment
            .fromFrameworkCommitment(_new);
        uint256 numParticipants = _old.participants.length;

        if (oldCommitment.furtherVotesRequired == 0) {
            validateConsensusCommitment(oldCommitment);
        } else {
            validateProposeCommitment(oldCommitment);
        }

        if (newCommitment.furtherVotesRequired == 0) {
            validateConsensusCommitment(newCommitment);
        } else {
            validateProposeCommitment(newCommitment);
        }

        return
            validPropose(oldCommitment, newCommitment, numParticipants) ||
                validVote(oldCommitment, newCommitment) ||
                validVeto(oldCommitment, newCommitment) ||
                validPass(oldCommitment, newCommitment) ||
                validFinalVote(oldCommitment, newCommitment) ||
                invalidTransition();
    }

    function invalidTransition() internal pure returns (bool) {
        revert("ConsensusApp: No valid transition found for commitments");
    }

    // Transition validations

    function validPropose(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment,
        uint256 numParticipants
    ) internal pure returns (bool) {
        if (furtherVotesRequiredInitialized(newCommitment, numParticipants)) {
            validateBalancesUnchanged(oldCommitment, newCommitment);
            return true;
        } else {
            return false;
        }
    }

    function validVote(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) internal pure returns (bool) {
        if (
            oldCommitment.furtherVotesRequired > 1 &&
            furtherVotesRequiredDecremented(oldCommitment, newCommitment)
        ) {
            validateBalancesUnchanged(oldCommitment, newCommitment);
            validateProposalsUnchanged(oldCommitment, newCommitment);
            return true;
        } else {
            return false;
        }
    }

    function validFinalVote(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) internal pure returns (bool) {
        if (
            oldCommitment.furtherVotesRequired == 1 &&
            newCommitment.furtherVotesRequired == 0 &&
            outcomeUpdated(oldCommitment, newCommitment)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function validVeto(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) internal pure returns (bool) {
        if (
            oldCommitment.furtherVotesRequired > 0 &&
            newCommitment.furtherVotesRequired == 0 &&
            outcomeUnchanged(oldCommitment, newCommitment)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function validPass(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) internal pure returns (bool) {
        if (oldCommitment.furtherVotesRequired == 0 && newCommitment.furtherVotesRequired == 0) {
            validateBalancesUnchanged(oldCommitment, newCommitment);
            return true;
        } else {
            return false;
        }
    }

    // Helper validators

    function validateBalancesUnchanged(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) private pure {
        require(
            encodeAndHashOutcome(oldCommitment.currentOutcome) ==
                encodeAndHashOutcome(newCommitment.currentOutcome),
            "ConsensusApp: 'outcome' must be the same between commitments."
        );
    }

    function validateProposalsUnchanged(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) private pure {
        require(
            encodeAndHashOutcome(oldCommitment.proposedOutcome) ==
                encodeAndHashOutcome(newCommitment.proposedOutcome),
            "ConsensusApp: 'proposedOutcome' must be the same between commitments."
        );
    }

    function validateConsensusCommitment(
        ConsensusCommitment.ConsensusCommitmentStruct memory commitment
    ) internal pure {
        require(
            commitment.furtherVotesRequired == 0,
            "ConsensusApp: 'furtherVotesRequired' must be 0 during consensus."
        );
        require(
            commitment.proposedOutcome.length == 0,
            "ConsensusApp: 'proposedOutcome' must be reset during consensus."
        );
    }

    function validateProposeCommitment(
        ConsensusCommitment.ConsensusCommitmentStruct memory commitment
    ) internal pure {
        require(
            commitment.furtherVotesRequired != 0,
            "ConsensusApp: 'furtherVotesRequired' must not be 0 during propose."
        );
        require(
            commitment.proposedOutcome.length > 0,
            "ConsensusApp: 'proposedOutcome' must not be reset during propose."
        );
    }

    // Booleans

    function furtherVotesRequiredInitialized(
        ConsensusCommitment.ConsensusCommitmentStruct memory commitment,
        uint256 numParticipants
    ) private pure returns (bool) {
        return (commitment.furtherVotesRequired == numParticipants - 1);
    }

    function furtherVotesRequiredDecremented(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) private pure returns (bool) {
        return (newCommitment.furtherVotesRequired == oldCommitment.furtherVotesRequired - 1);
    }

    function outcomeUpdated(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) private pure returns (bool) {
        return (
            encodeAndHashOutcome(oldCommitment.proposedOutcome) ==
                encodeAndHashOutcome(newCommitment.currentOutcome)
        );
    }

    function outcomeUnchanged(
        ConsensusCommitment.ConsensusCommitmentStruct memory oldCommitment,
        ConsensusCommitment.ConsensusCommitmentStruct memory newCommitment
    ) private pure returns (bool) {
        return (
            encodeAndHashOutcome(oldCommitment.currentOutcome) ==
                encodeAndHashOutcome(newCommitment.currentOutcome)
        );
    }

    function hasFurtherVotesNeededBeenInitialized(
        ConsensusCommitment.ConsensusCommitmentStruct memory commitment,
        uint256 numParticipants
    ) public pure returns (bool) {
        return commitment.furtherVotesRequired == numParticipants - 1;
    }

    // helpers

    function encodeAndHashOutcome(Outcome.HolderAndOutcome[] memory outcome) internal pure returns (bytes32) {
        return keccak256(abi.encode(outcome));
    }

}
