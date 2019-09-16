pragma solidity ^0.5.11;
pragma experimental ABIEncoderV2;

library Outcome {
    //An outcome is an array of LabelledAssetOutcomes
    // Outcome = LabelledAssetOutcome[]
    // LabelledAssetOutome = (AssetID, AllocationOrGuarantee)
    // AllocationOrGuarantee = Allocation | Guarantee
    // Allocation = AllocationItem[]
    // AllocationItem = (Destination, Amount)
    // Guarantee = (ChannelAddress, Destination[])
    // Destination = ChannelAddress | ExternalAddress

    struct LabelledAssetOutcome {
        address assetHolderAddress;
        bytes assetOutcomeBytes; // abi.encode(AssetOutcome)
    }

    enum OutcomeType {Allocation, Guarantee}

    struct AssetOutcome {
        uint8 outcomeType; // OutcomeType.Allocation or OutcomeType.Guarantee
        bytes allocationOrGuaranteeBytes; // abi.encode(AllocationItem[]) or abi.encode(Guarantee), depending on OutcomeType
    }

    // reserve Allocation to refer to AllocationItem[]
    struct AllocationItem {
        bytes32 destination;
        uint256 amount;
    }

    struct Guarantee {
        bytes32 targetChannelId;
        bytes32[] destinations;
    }

}
