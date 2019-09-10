pragma solidity ^0.5.11;
pragma experimental ABIEncoderV2;

import './ForceMoveApp.sol';

contract ConsensusApp is ForceMoveApp {
    struct ConsensusAppData {
        uint32 furtherVotesRequired;
        bytes proposedOutcome;
    }

    function appData(bytes memory appDataBytes) internal pure returns (ConsensusAppData memory) {
        return abi.decode(appDataBytes, (ConsensusAppData));
    }

    function validTransition(
        VariablePart memory a,
        VariablePart memory b,
        uint256 turnNumB, // unused
        uint256 numParticipants
    ) public pure returns (bool) {

        ConsensusAppData memory appDataA = appData(a.appData);
        ConsensusAppData memory appDataB = appData(b.appData);

        if(appDataB.furtherVotesRequired == 0) { // final vote or veto/pass
            require(appDataB.proposedOutcome.length == 0, 'ConsensusApp: proposedOutcome must be empty, if furtherVotesRequired = 0');

            if(!identical(a.outcome, b.outcome)) { // not a veto/pass => final vote
                require(appDataA.furtherVotesRequired == 1,'ConsensusApp: invalid final vote, furtherVotesRequired must transition from 1');
                require(identical(appDataA.proposedOutcome, b.outcome), 'ConsensusApp: invalid final vote, outcome must equal previous proposedOutcome');
            }
        } else { // propose or vote
            require(identical(a.outcome, b.outcome), 'ConsensusApp: current outcome must not change in propose or vote');

            if(appDataA.furtherVotesRequired == 0) { // propose
                require(appDataB.furtherVotesRequired == numParticipants - 1, 'ConsensusApp: must set furtherVotesRequired when proposing');
            } else { // vote
                require(appDataB.furtherVotesRequired == appDataA.furtherVotesRequired - 1, 'ConsensusApp: invalid vote, must decrease votes required');
                require(identical(appDataA.proposedOutcome, appDataB.proposedOutcome), 'ConsensusApp: invalid vote, proposedOutcome must not change');
            }
        }

        return true;
    }

    // Utilitiy helpers

    function identical(bytes memory a, bytes memory b) internal pure returns (bool) {
        return (keccak256(abi.encode(a)) == keccak256(abi.encode(b)));
    }

}
