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

| >                                                                                               | 0xETHAssetHolder                                 | 0                                                  | 0xAlice | 5   | 0xBob | 2   | 0xDAIAssetHolder | ... |
| ----------------------------------------------------------------------------------------------- | ------------------------------------------------ | -------------------------------------------------- | ------- | --- | ----- | --- | ---------------- | --- |
|                                                                                                 |                                                  | <td colspan="4" align="center">AllocationItem</td> |         |     |
|                                                                                                 | <td colspan="5" align="center">AssetOutcome</td> |                                                    |         |
| <td colspan="6" align="center">OutcomeItem</td> <td colspan="6" align="center">OutcomeItem</td> |
| <td colspan="8" align="center">Outcome</td>                                                     |

```
Outcome = OutcomeItem[]
OutcomeItem = (AssetHolderAddress, AssetOutcome)
AssetOutcome = (AssetOutcomeType, Allocation | Guarantee)
Allocation = AllocationItem[]
AllocationItem = (Destination, Amount)
Guarantee = (ChannelAddress, Destination[])
Destination = ChannelAddress | ExternalAddress
```

## Implementation

In `Outcome2.sol`:

```solidity
pragma solidity ^0.5.11;
pragma experimental ABIEncoderV2;

library Outcome {
  //An outcome is an array of OutcomeItems
  // Outcome = OutcomeItem[]
  // LabelledAssetOutome = (AssetID, AllocationOrGuarantee)
  // AllocationOrGuarantee = Allocation | Guarantee
  // Allocation = AllocationItem[]
  // AllocationItem = (Destination, Amount)
  // Guarantee = (ChannelAddress, Destination[])
  // Destination = ChannelAddress | ExternalAddress

  struct OutcomeItem {
    address assetHolderAddress;
    bytes assetOutcomeBytes; // abi.encode(AssetOutcome)
  }

  enum AssetOutcomeType {Allocation, Guarantee}

  struct AssetOutcome {
    uint8 assetOutcomeType; // AssetOutcomeType.Allocation or AssetOutcomeType.Guarantee
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
TODO migrate codebase to Outcome2.sol
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
