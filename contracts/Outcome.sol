pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Commitment.sol";

library Outcome {
    struct allocation {
        address participant;
        uint256 amount;
    }
    // e.g. {0xAlice, 5}

    struct SingleAssetOutcome {
        address assetHolder;
        Commitment.CommitmentStruct challengeCommitment;
        uint256 finalizedAt;
        allocation[] allocations;
    }

     // e.g.
    //      {
    //         0xAssetHolder1,
    //         {commitmentStruct},
    //         now,
    //         [{0xAlice, 5}, {0XBob, 3}]
    //     }

    // an "Outcome" is simply an array of SingleAssetOutcomes
}
