pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Commitment.sol";

library Outcome {
    struct allocation { // TODO  allocation -> Allocation
        address participant; // TODO rename to destination (could be a channel and not a participant)
        uint256 amount;
    }
    // e.g. {0xAlice, 5}

    struct SingleAssetOutcome {
        address assetHolder;
        allocation[] allocations;
        address guaranteedChannel; // set to zero address unless a guarantor channel
    }

    // e.g.
    //      {
    //         0xAssetHolder1,
    //         {commitmentStruct},
    //         now,
    //         [{0xAlice, 5}, {0XBob, 3}]
    //     }

    // an outcome is simply an array of SingleAssetOutcomes

    struct SingleAssetOutcomeWithMetaData {
        SingleAssetOutcome singleAssetOutcome;
        uint256 finalizedAt;
    } // for on chain use only
}
