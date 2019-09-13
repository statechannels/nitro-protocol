---
id: push-outcome
title: pushOutcome
---

The pushOutcome method allows one or more allocations to be registered against a channel in a number of AssetHolder contracts (specified by the outcome stored in this contract).

:::important
The names of these objects needs a review.
:::

Signature:

```solidity
    function pushOutcome(
        bytes32 channelId,
        uint256 turnNumRecord,
        uint256 finalizesAt,
        bytes32 stateHash,
        address challengerAddress,
        bytes memory outcome
    ) public
```

## Checks:

- Does the submitted data hash to the channel storage for this channel?

## Effects

- decode `assetOutcomes` from `outcome`
- for each AssetHolder specified in `assetOutcomes`, call `setOutcome`.
