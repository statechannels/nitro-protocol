---
id: version-0.1.0-quick-start
title: Quick Start
original_id: quick-start
---

How do I write a DApp (or convert an existing DApp) to run in a Nitro state channel?

1. The first step is to cast your application as a state machine. In particular, you must author a single smart contract, conforming to the `ForceMoveApp` interface. [This interface](./adjudicator/transition-rules#application-specific-transition-rules) calls for an application-specific `validTransition(a,b)` function. This function needs to decode the `appData`, from state channel updates `a` and `b`, and decide if `b` is an acceptable transition from `a`. For example, in a game of chess, the position of the king in `b.appData` must be within one square of its position in `a.appData`.

   You may wish to encode economic incentives into this state machine.

2. This code can then be deployed on chain and the address of the contract saved. Participants also compute the [`channelId`](./adjudicator/state-format#ChannelId).
3. Participants may exchange opening state updates to confirm their participation in the channel. All state updates for the channel include a reference to the address of the deployed, application-specific state machine.
4. Deposits (ETH and/or Tokens) are then made against the `channelId`, by interfacing with the relevant AssetHolder contracts.
5. Participants exchange state updates and the default outcome is updated.
6. In the case of inactivity, participants may call `forceMove` on the adjudicator
7. Either the dispute will be resolved and the channel continues (goto 5) or the channel is finalized. Otherwise if all participants agree to close the channel, it can be finalized more cheaply.
8. The outcome is pushed from the Adjudicator to the AssetHolders by calling `pushOutcome`.
9. Funds are released from the AssetHolders.

In this example, assets are held on chain **directly** against the state channel. The state channel is said to be directly funded, a situation we represent thus:

<div class="mermaid" align="center">
graph TD
linkStyle default interpolate basis
BC[fa:fa-landmark]
C((C))
BC-->C
</div>

A more advanced technique is to run the DApp in a ledger-funded or virtually-funded state channel -- see the section on [auxiliary protocols](./auxiliary-protocols).
