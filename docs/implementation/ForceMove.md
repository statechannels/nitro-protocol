---
id: ForceMove
title: ForceMove
---

## Functions:
- [`getData`](#getData)
- [`forceMove`](#forceMove)
- [`respond`](#respond)
- [`refute`](#refute)
- [`checkpoint`](#checkpoint)
- [`conclude`](#conclude)
- [`_requireThatChallengerIsParticipant`](#_requireThatChallengerIsParticipant)
- [`_isAddressInArray`](#_isAddressInArray)
- [`_validSignatures`](#_validSignatures)
- [`_acceptableWhoSignedWhat`](#_acceptableWhoSignedWhat)
- [`_recoverSigner`](#_recoverSigner)
- [`_requireStateSupportedBy`](#_requireStateSupportedBy)
- [`_requireValidTransition`](#_requireValidTransition)
- [`_requireValidTransition`](#_requireValidTransition)
- [`_bytesEqual`](#_bytesEqual)
- [`_clearChallenge`](#_clearChallenge)
- [`_requireChannelOpen`](#_requireChannelOpen)
- [`_requireMatchingStorage`](#_requireMatchingStorage)
- [`_requireIncreasedTurnNumber`](#_requireIncreasedTurnNumber)
- [`_requireNonDecreasedTurnNumber`](#_requireNonDecreasedTurnNumber)
- [`_requireSpecificChallenge`](#_requireSpecificChallenge)
- [`_requireOngoingChallenge`](#_requireOngoingChallenge)
- [`_requireChannelNotFinalized`](#_requireChannelNotFinalized)
- [`_hashChannelStorage`](#_hashChannelStorage)
- [`_getData`](#_getData)
- [`_matchesHash`](#_matchesHash)
- [`_hashState`](#_hashState)
- [`_hashOutcome`](#_hashOutcome)
- [`_getChannelId`](#_getChannelId)


<a id=getData />
## `getData`

```solidity
function getData(bytes32 channelId) → (uint48 finalizesAt, uint48 turnNumRecord, uint160 fingerprint)
```

Calls internal method _getData

    


<a id=forceMove />
## `forceMove`

```solidity
function forceMove(struct ForceMove.FixedPart fixedPart, uint48 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat, struct ForceMove.Signature challengerSig)
```

No description



<a id=respond />
## `respond`

```solidity
function respond(address challenger, bool[2] isFinalAB, struct ForceMove.FixedPart fixedPart, struct ForceMoveApp.VariablePart[2] variablePartAB, struct ForceMove.Signature sig)
```

No description



<a id=refute />
## `refute`

```solidity
function refute(uint48 refutationStateTurnNum, address challenger, bool[2] isFinalAB, struct ForceMove.FixedPart fixedPart, struct ForceMoveApp.VariablePart[2] variablePartAB, struct ForceMove.Signature refutationStateSig)
```

No description



<a id=checkpoint />
## `checkpoint`

```solidity
function checkpoint(struct ForceMove.FixedPart fixedPart, uint48 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat)
```

No description



<a id=conclude />
## `conclude`

```solidity
function conclude(uint48 largestTurnNum, struct ForceMove.FixedPart fixedPart, bytes32 appPartHash, bytes32 outcomeHash, uint8 numStates, uint8[] whoSignedWhat, struct ForceMove.Signature[] sigs)
```

No description



<a id=_requireThatChallengerIsParticipant />
## `_requireThatChallengerIsParticipant`

```solidity
function _requireThatChallengerIsParticipant(bytes32 supportedStateHash, address[] participants, struct ForceMove.Signature challengerSignature) → (address challenger)
```

No description



<a id=_isAddressInArray />
## `_isAddressInArray`

```solidity
function _isAddressInArray(address suspect, address[] addresses) → (bool)
```

No description



<a id=_validSignatures />
## `_validSignatures`

```solidity
function _validSignatures(uint256 largestTurnNum, address[] participants, bytes32[] stateHashes, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat) → (bool)
```

No description



<a id=_acceptableWhoSignedWhat />
## `_acceptableWhoSignedWhat`

```solidity
function _acceptableWhoSignedWhat(uint8[] whoSignedWhat, uint256 largestTurnNum, uint256 nParticipants, uint256 nStates) → (bool)
```

No description



<a id=_recoverSigner />
## `_recoverSigner`

```solidity
function _recoverSigner(bytes32 _d, struct ForceMove.Signature sig) → (address)
```

No description



<a id=_requireStateSupportedBy />
## `_requireStateSupportedBy`

```solidity
function _requireStateSupportedBy(uint256 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, bytes32 channelId, struct ForceMove.FixedPart fixedPart, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat) → (bytes32)
```

No description



<a id=_requireValidTransition />
## `_requireValidTransition`

```solidity
function _requireValidTransition(uint256 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, bytes32 channelId, struct ForceMove.FixedPart fixedPart) → (bytes32[])
```

No description



<a id=_requireValidTransition />
## `_requireValidTransition`

```solidity
function _requireValidTransition(uint256 nParticipants, bool[2] isFinalAB, struct ForceMoveApp.VariablePart[2] ab, uint256 turnNumB, address appDefinition) → (bool)
```

No description



<a id=_bytesEqual />
## `_bytesEqual`

```solidity
function _bytesEqual(bytes left, bytes right) → (bool)
```

No description



<a id=_clearChallenge />
## `_clearChallenge`

```solidity
function _clearChallenge(bytes32 channelId, uint256 newTurnNumRecord)
```

No description



<a id=_requireChannelOpen />
## `_requireChannelOpen`

```solidity
function _requireChannelOpen(bytes32 channelId)
```

No description



<a id=_requireMatchingStorage />
## `_requireMatchingStorage`

```solidity
function _requireMatchingStorage(struct ForceMove.ChannelStorage cs, bytes32 channelId)
```

No description



<a id=_requireIncreasedTurnNumber />
## `_requireIncreasedTurnNumber`

```solidity
function _requireIncreasedTurnNumber(bytes32 channelId, uint48 newTurnNumRecord)
```

No description



<a id=_requireNonDecreasedTurnNumber />
## `_requireNonDecreasedTurnNumber`

```solidity
function _requireNonDecreasedTurnNumber(bytes32 channelId, uint48 newTurnNumRecord)
```

No description



<a id=_requireSpecificChallenge />
## `_requireSpecificChallenge`

```solidity
function _requireSpecificChallenge(struct ForceMove.ChannelStorage cs, bytes32 channelId)
```

No description



<a id=_requireOngoingChallenge />
## `_requireOngoingChallenge`

```solidity
function _requireOngoingChallenge(bytes32 channelId)
```

No description



<a id=_requireChannelNotFinalized />
## `_requireChannelNotFinalized`

```solidity
function _requireChannelNotFinalized(bytes32 channelId)
```

No description



<a id=_hashChannelStorage />
## `_hashChannelStorage`

```solidity
function _hashChannelStorage(struct ForceMove.ChannelStorage channelStorage) → (bytes32 newHash)
```

No description



<a id=_getData />
## `_getData`

```solidity
function _getData(bytes32 channelId) → (uint48 turnNumRecord, uint48 finalizesAt, uint160 fingerprint)
```

No description



<a id=_matchesHash />
## `_matchesHash`

```solidity
function _matchesHash(struct ForceMove.ChannelStorage cs, bytes32 h) → (bool)
```

No description



<a id=_hashState />
## `_hashState`

```solidity
function _hashState(uint256 turnNumRecord, bool isFinal, bytes32 channelId, struct ForceMove.FixedPart fixedPart, bytes appData, bytes32 outcomeHash) → (bytes32)
```

No description



<a id=_hashOutcome />
## `_hashOutcome`

```solidity
function _hashOutcome(bytes outcome) → (bytes32)
```

No description



<a id=_getChannelId />
## `_getChannelId`

```solidity
function _getChannelId(struct ForceMove.FixedPart fixedPart) → (bytes32 channelId)
```

No description



## Events:
- [`ChallengeRegistered`](#ChallengeRegistered)
- [`ChallengeCleared`](#ChallengeCleared)
- [`Concluded`](#Concluded)

<a id=ChallengeRegistered />
## `ChallengeRegistered`
No description

<a id=ChallengeCleared />
## `ChallengeCleared`
No description

<a id=Concluded />
## `Concluded`
No description

