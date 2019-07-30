pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Commitment.sol";

library Outcome {
    struct HolderAndOutcome {
      address assetHolder;
      bytes assetOutcome; // AssetOutcome
    }

    enum OutcomeType { Allocation, Guarantee }

    struct AssetOutcome {
      uint8 outcomeType; // OutcomeType
      bytes outcomeContent; // either AllocationItem[] or Guarantee, depending on OutcomeType
    }

    // reserve Allocation to refer to AllocationItem[]
    struct AllocationItem {
      address destination;
      uint256 amount;
    }
    // e.g. {0xAlice, 5}

    struct Guarantee {
      address guaranteedChannelId;
      address[] destinations;
    }

    function getAssetOutcome(bytes memory assetOutcomeBytes) public pure returns (AssetOutcome memory) {
      return abi.decode(assetOutcomeBytes, AssetOutcome);
    }

    function isAllocation(AssetOutcome memory assetOutcome) public pure returns (bool) {
      return assetOutcome.outcomeType == OutcomeType.Allocation;
    }

    // should have determined that isAllocation before calling
    function getAllocation(bytes memory outcomeContent) public pure returns (AllocationItem[] memory) {
      return abi.decode(outcomeContent, AllocationItem[]);
    }

    function isGuarantee(AssetOutcome memory assetOutcome) public pure returns (bool) {
      return assetOutcome.outcomeType == OutcomeType.Guarantee;
    }

    // should have determined that isGuarantee before calling
    function getGuarantee(bytes memory outcomeContent) public pure returns (Guarantee memory) {
      return abi.decode(outcomeContent, Guarantee);
    }
}
