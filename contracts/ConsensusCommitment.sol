
pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

import "./Commitment.sol";
import "./Outcome.sol";

library ConsensusCommitment {
    using Commitment for Commitment.CommitmentStruct;

    struct AppAttributes {
        uint32 furtherVotesRequired;
        Outcome.TokenOutcomeItem[] proposedOutcome;
    }

    struct ConsensusCommitmentStruct {
        uint32 furtherVotesRequired;
        Outcome.TokenOutcomeItem[] currentOutcome;
        Outcome.TokenOutcomeItem[] proposedOutcome;
    }

    function getAppAttributesFromFrameworkCommitment(
        Commitment.CommitmentStruct memory frameworkCommitment
    ) public pure returns (AppAttributes memory) {
        return abi.decode(frameworkCommitment.appAttributes, (AppAttributes));
    }

    function fromFrameworkCommitment(Commitment.CommitmentStruct memory frameworkCommitment)
        public
        pure
        returns (ConsensusCommitmentStruct memory)
    {
        AppAttributes memory appAttributes = abi.decode(
            frameworkCommitment.appAttributes,
            (AppAttributes)
        );

        return
            ConsensusCommitmentStruct(
                appAttributes.furtherVotesRequired,
                frameworkCommitment.outcome,
                appAttributes.proposedOutcome
            );
    }
}