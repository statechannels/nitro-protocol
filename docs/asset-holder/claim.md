---
id: claim
title: claimAll
---

The claimAll method takes the funds escrowed against a guarantor channel, and attempts to transfer them to the beneficiaries of the target channel specified by the guarantor. The transfers are first attempted in a nonstandard priority order given by the guarantor, so that beneficiaries of underfunded channels may not receive a transfer, depending on their nonstandard priority. Full or partial transfers to a beneficiary results in deletion or reduction of that beneficiary's allocation (respectively). Surplus funds are then subject to another attempt to transfer them to the beneficiaries of the target channel, but this time with the standard priority order given by the target channel. Any funds that still remain after this step remain in escrow against the guarantor.

As with transferAll, a transfer to another channel results in explicit escrow of funds against that channel. A transfer to an external address results in ETH or ERC20 tokens being transferred out of the AssetHolder contract.

Signature:

```solidity
   function claimAll(
        bytes32 channelId,
        bytes calldata guaranteeBytes,
        bytes calldata allocationBytes
    ) external
```

## Implementation

- First pays out according to the allocation of the `guaranteedAddress` but with priorities set by the guarantee.
- Pays any remaining funds out according to the default priorities.

`claimAll(bytes32 guarantorChannelId, bytes32 targetChannelId, bytes32[] destinations, AllocationItem[] allocation)`

- checks that `outcomes[guarantorChannelId]` is equal to `hash(1, (targetChannelId, destinations))`, where `1` signifies an outcome of type `GUARANTEE`
- checks that `outcomes[targetChannelId]` is equal to `hash(0, allocation)`
- `let balance = balances[guarantorChannelId]`
- k = 0
- let payouts = []
- for 0 <= i < destinations.length
  - let destination = destinations[i]
  - if balance == 0
    - break
  - for 0 <= j < allocation.length
    - if allocations[j].destination == destination
      - let amount = allocations[j].amount
      - if balance >= amount
        - payouts[k] = (destination, amount)
        - k++
        - balance -= amount
        - delete(allocations[j])
        - break
      - else
        - payouts[k] = (destination, balance)
        - k++
        - allocations[j].value = amount - balance
        - balance = 0
        - break
- // allocate the rest as in transferAll
- let newAllocation = []
- let j = 0
- for 0 <= i < allocation.length
  - let (destination, amount) = allocation[i]
  - if balance == 0
    - newAllocation[j] = (destination, amount)
    - j++
  - elsif balance <= amount
    - payouts[k] = (destination, balance)
    - k++
    - newAllocation[j] = (destination, amount - balance)
    - balance = 0
  - else
    - payouts[k] = (destination, amount)
    - k++
    - balance -= amount
- sets `balances[guarantorChannelId] = balance`
  - note: must do this before calling any external contracts to prevent re-entrancy bugs
- sets `outcomes[guarantorChannelId] = hash(newAllocation)` or clears if `newAllocation = []`
- for each payout
  - if payout is an external address
    - do an external transfer to the address
  - else
    - `balances[destination] += payout.amount`

* when can we delete the guarantee? only when the allocation has been deleted. but this means we can only delete one guarantee. So maybe just don't bother
