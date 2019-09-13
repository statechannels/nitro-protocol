---
id: transfer
title: transferAll
---

The transferAll method takes the funds escrowed against a channel, and attempts to transfer them to the beneficiaries of that channel. The transfers are attempted in priority order, so that beneficiaries of underfunded channels may not receive a transfer, depending on their priority. Surplus funds remain in escrow against the channel. Full or partial transfers to a beneficiary results in deletion or reduction of that beneficiary's allocation (respectively). A transfer to another channel results in explicit escrow of funds against that channel. A transfer to an external address results in ETH or ERC20 tokens being transferred out of the AssetHolder contract.

```solidity
function transferAll(bytes32 channelId, bytes calldata allocationBytes) external
```

Algorithm:

- checks that `outcomes[channelAddress]` is equal to `hash(0, allocation)`, where `0` signifies an outcome type of `ALLOCATION`
- `let balance = balances[channelAddress]`
- let payouts = []
- let newAllocation = []
- let j = 0
- for 0 <= i < allocation.length
  - let (destination, amount) = allocation[i]
  - if balance == 0
    - newAllocation[j] = (destination, amount)
    - j++
  - else if balance <= amount
    - payouts[i] = (destination, balance)
    - newAllocation[j] = (destination, amount - balance)
    - balance = 0
  - else
    - payouts[i] = (destination, amount)
    - balance -= amount
- sets `balances[channelAddress] = balance`
  - note: must do this before calling any external contracts to prevent re-entrancy bugs
- sets `outcomes[channelAddress] = hash(newAllocation)` or clears if `newAllocation = []`
- for each payout
  - if payout is an external address
    - do an external transfer to the address
  - else
    - `balances[destination] += payout.amount`
