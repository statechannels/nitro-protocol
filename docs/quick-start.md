---
id: quick-start
title: Quick Start
---

How do I write a DApp (or convert an existing DApp) to run in a Nitro state channel?

1. The first step is to cast your application as a state machine. In particular, you must author a single smart contract, conforming to the `ForceMoveApp` interface. This interface calls for an application-specific `validTransition(a,b)` function. This function needs to decode the `appData`, from state channel updates `a` and `b`, and decide if `b` is an acceptable transition from `a`. For example, in a game of chess, the position of the king in `b.appData` must be within one square of its position in `a.appData`.

   You may wish to encode economic incentives into this state machine.

2. This code can then be deployed on chain and the address of the contract saved.
3. Participants may exchange opening state updates to confirm their participation in the channel.
4. Deposits (ETH and/or Tokens) are then made by interfacing with the relevant AssetHolder contracts.
5. Participants exchange state updates and the default outcome is updated.
6. In the case of inactivity, participants may call `forceMove` on the adjudicator
7. Either the dispute will be resolved and the channel continues (goto 5) or the channel is finalized. Otherwise if all participants agree to close the channel, it can be finalized more cheaply.
8. The outcome is pushed from the Adjudicator to the AssetHolders by calling `pushOutcome`.
9. Funds are released from the AssetHolders.

A more advanced technique is to run the DApp in a ledger-funded or virtually-funded state channel.

## Ledger-funding

This technique involves opening and funding a "consensus game" or "ledger" state channel between the participants, following the steps above. The consensus game state machine is a core part of nitro protocol and you will find an implementation in this repository. It describes a very simple state channel whose sole purpose is to fund other channels, by declaring funds be directed to a channel address instead of an externally owned address.

Once in place, the ledger channel can be updated to fund any other state channel the participants are interested in. Such a channel is said to be ledger-funded; no blockchain transactions are required to fund or de-fund a ledger-funded channel. Disputes are still resolved on chain.

## Virtual-funding

This technique leverages a pair (or more) of existing ledger channels to fund a channel among participants who are not all participating in those ledger channels. To be opened and closed safely, guarantor channels are used. A channel that is funded in this way is said to be virtually-funded; no blockchain transactions are required to fund or de-fund a virtually-funded channel, and the participants do not need to share an on chain deposit. Instead they need to have a ledger channel open with a shared intermediary. Disputes are still resolved on chain.
