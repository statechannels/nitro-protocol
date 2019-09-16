---
id: outcomes
title: Outcomes
---

ForceMove specifies that a state should have a default `outcome` but does not specify the format of that `outcome`, and simply treats it as an unstructured `bytes` field. In this section we look at the outcome formats needed for Nitro.

## Specification

Nitro supports multiple different assets (e.g. ETH and one or more ERC20s) being held in the same channel.

The adjudicator stores an encoded `outcome` for each finalized channel. As a part of the process triggered by [`pushOutcome`](./adjudicator/push-outcome), a decoded outcome will be stored across multiple asset holder contracts in a number of hashes. A decoded `outcome` is therefore an array of `LabelledAssetOutcomes`. These individual `LabelledAssetOutcomes` contain a pointer to the asset holder contract in question, as well as some `bytes` that encode a `AssetOutcome`. This data structure contains some more `bytes` encoding either an allocation or a guarantee, as well as the label: an integer which indicates which. The hash of the `AssetOutcome` `bytes` are stored by the asset holder contract specified.

## Example of an outcome data structure

The outcome is stored in two places: first, as a single hash in the adjudicator contract; second, in multiple hashes across multiple asset holder contracts.

<div class="mermaid">
graph TD
linkStyle default interpolate basis
ob["outcomeBytes"]
subgraph Adjudicator
    ocH[outcomeHash]
end
ob-->|.hash|ocH
subgraph outcome
    LabelledAssetOutcome0["outcome[0]"]
    LabelledAssetOutcome1["outcome[1]"]
    LabelledAssetOutcome2["outcome[2]"]
end
ob-->|".decode[0]"|LabelledAssetOutcome0
ob-->|".decode[1]"|LabelledAssetOutcome1
ob-->|".decode[2]"|LabelledAssetOutcome2
LabelledAssetOutcome1-->|.AssetHolderAddress|ah["'0xAssetHolder1'"]
LabelledAssetOutcome1-->|.assetOutcomeBytes.decode|ao["AssetOutcome"]
LabelledAssetOutcome1-->|.assetOutcomeBytes.hash|aoH
ao-->|.outcomeType|0
ao-->|".allocationOrGuaranteeBytes.decode[0]"|AI0
ao-->|".allocationOrGuaranteeBytes.decode[1]"|AI1
AI0["AllocationItem[0]"]
AI1["AllocationItem[1]"]
subgraph AssetHolder: 0xAssetHolder1
    aoH["assetOutcomeHash"]
end
AI0-->|".destination"|alice["'0xAlice'"]
AI0-->|".amount"|four["'0x4'"]
AI1-->|".destination"|bob["'0xBob'"]
AI1-->|".amount"|six["'0x6'"]
</div>

```
Outcome = AssetOutcome[]
AssetOutcome = (AssetID, AllocationOrGuarantee)
AllocationOrGuarantee = Allocation | Guarantee
Allocation = AllocationItem[]
AllocationItem = (Destination, Amount)
Guarantee = (ChannelAddress, Destination[])
Destination = ChannelAddress | ExternalAddress
```

Destinations are

An allocation determines

## Implementation

In `Outcome2.sol`:

```solidity
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
```

:::warning
TODO move to Outcome2.sol
:::

### Formats

| **Field**                    | **Data type**            | **Definition / Explanation**                                                                                |
| :--------------------------- | :----------------------- | :---------------------------------------------------------------------------------------------------------- |
| `outcome`                    | `LabelledAssetOutcome[]` |
| `assetHolderAddress`         | `address`                | address of asset holder contract                                                                            |
| `assetOutcomeBytes`          | `bytes`                  | abi encoded `AssetOutcome`                                                                                  |
| `outcomeType`                | `uint8`                  | specifies either allocation or guarantee                                                                    |
| `allocationOrGuaranteeBytes` | `bytes`                  | abi.encode(AllocationItem[]) or abi.encode(Guarantee), depending on OutcomeType                             |  |
| `targetChannelId`            | `bytes32`                | The channelId that this guarantor channel is guaranteeing                                                   |
| `destinations[]`             | `bytes32[]`              | Each taken to be an ExternalAddress if starts with 12 bytes of leading zeros and a ChannelAddress otherwise |
