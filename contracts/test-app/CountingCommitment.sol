pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

import "../Commitment.sol";
import "../Outcome.sol";

library CountingCommitment {
    using Commitment for Commitment.CommitmentStruct;

    struct AppAttributes {
        uint256 appCounter;
    }

    struct CountingCommitmentStruct {
        uint256 appCounter;
        Outcome.SingleAssetOutcome[] outcome;
    }

    function fromFrameworkCommitment(Commitment.CommitmentStruct memory frameworkCommitment)
        public
        pure
        returns (CountingCommitmentStruct memory)
    {
        AppAttributes memory appAttributes = abi.decode(
            frameworkCommitment.appAttributes,
            (AppAttributes)
        );

        return
            CountingCommitmentStruct(
                appAttributes.appCounter,
                frameworkCommitment.outcome
            );
    }
}
