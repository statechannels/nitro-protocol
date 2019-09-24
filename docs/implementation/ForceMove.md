---
id: ForceMove
title: ForceMove
---

The ForceMove contract allows state channels to be adjudicated and finalized.

There are two ways in which a channel can finalize 
- A ForceMove (challenge) is registered and not cleared before a timeout elapses
- The participants collaboratively conclude the channel

# Functions:
- [`getData(bytes32 channelId)`](#ForceMove-getData-bytes32-)
- [`forceMove(struct ForceMove.FixedPart fixedPart, uint48 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat, struct ForceMove.Signature challengerSig)`](#ForceMove-forceMove-struct-ForceMove-FixedPart-uint48-struct-ForceMoveApp-VariablePart---uint8-struct-ForceMove-Signature---uint8---struct-ForceMove-Signature-)
- [`respond(address challenger, bool[2] isFinalAB, struct ForceMove.FixedPart fixedPart, struct ForceMoveApp.VariablePart[2] variablePartAB, struct ForceMove.Signature sig)`](#ForceMove-respond-address-bool-2--struct-ForceMove-FixedPart-struct-ForceMoveApp-VariablePart-2--struct-ForceMove-Signature-)
- [`refute(uint48 refutationStateTurnNum, address challenger, bool[2] isFinalAB, struct ForceMove.FixedPart fixedPart, struct ForceMoveApp.VariablePart[2] variablePartAB, struct ForceMove.Signature refutationStateSig)`](#ForceMove-refute-uint48-address-bool-2--struct-ForceMove-FixedPart-struct-ForceMoveApp-VariablePart-2--struct-ForceMove-Signature-)
- [`checkpoint(struct ForceMove.FixedPart fixedPart, uint48 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat)`](#ForceMove-checkpoint-struct-ForceMove-FixedPart-uint48-struct-ForceMoveApp-VariablePart---uint8-struct-ForceMove-Signature---uint8---)
- [`conclude(uint48 largestTurnNum, struct ForceMove.FixedPart fixedPart, bytes32 appPartHash, bytes32 outcomeHash, uint8 numStates, uint8[] whoSignedWhat, struct ForceMove.Signature[] sigs)`](#ForceMove-conclude-uint48-struct-ForceMove-FixedPart-bytes32-bytes32-uint8-uint8---struct-ForceMove-Signature---)
- [`_requireThatChallengerIsParticipant(bytes32 supportedStateHash, address[] participants, struct ForceMove.Signature challengerSignature)`](#ForceMove-_requireThatChallengerIsParticipant-bytes32-address---struct-ForceMove-Signature-)
- [`_isAddressInArray(address suspect, address[] addresses)`](#ForceMove-_isAddressInArray-address-address---)
- [`_validSignatures(uint256 largestTurnNum, address[] participants, bytes32[] stateHashes, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat)`](#ForceMove-_validSignatures-uint256-address---bytes32---struct-ForceMove-Signature---uint8---)
- [`_acceptableWhoSignedWhat(uint8[] whoSignedWhat, uint256 largestTurnNum, uint256 nParticipants, uint256 nStates)`](#ForceMove-_acceptableWhoSignedWhat-uint8---uint256-uint256-uint256-)
- [`_recoverSigner(bytes32 _d, struct ForceMove.Signature sig)`](#ForceMove-_recoverSigner-bytes32-struct-ForceMove-Signature-)
- [`_requireStateSupportedBy(uint256 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, bytes32 channelId, struct ForceMove.FixedPart fixedPart, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat)`](#ForceMove-_requireStateSupportedBy-uint256-struct-ForceMoveApp-VariablePart---uint8-bytes32-struct-ForceMove-FixedPart-struct-ForceMove-Signature---uint8---)
- [`_requireValidTransition(uint256 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, bytes32 channelId, struct ForceMove.FixedPart fixedPart)`](#ForceMove-_requireValidTransition-uint256-struct-ForceMoveApp-VariablePart---uint8-bytes32-struct-ForceMove-FixedPart-)
- [`_requireValidTransition(uint256 nParticipants, bool[2] isFinalAB, struct ForceMoveApp.VariablePart[2] ab, uint256 turnNumB, address appDefinition)`](#ForceMove-_requireValidTransition-uint256-bool-2--struct-ForceMoveApp-VariablePart-2--uint256-address-)
- [`_bytesEqual(bytes left, bytes right)`](#ForceMove-_bytesEqual-bytes-bytes-)
- [`_clearChallenge(bytes32 channelId, uint256 newTurnNumRecord)`](#ForceMove-_clearChallenge-bytes32-uint256-)
- [`_requireChannelOpen(bytes32 channelId)`](#ForceMove-_requireChannelOpen-bytes32-)
- [`_requireMatchingStorage(struct ForceMove.ChannelStorage cs, bytes32 channelId)`](#ForceMove-_requireMatchingStorage-struct-ForceMove-ChannelStorage-bytes32-)
- [`_requireIncreasedTurnNumber(bytes32 channelId, uint48 newTurnNumRecord)`](#ForceMove-_requireIncreasedTurnNumber-bytes32-uint48-)
- [`_requireNonDecreasedTurnNumber(bytes32 channelId, uint48 newTurnNumRecord)`](#ForceMove-_requireNonDecreasedTurnNumber-bytes32-uint48-)
- [`_requireSpecificChallenge(struct ForceMove.ChannelStorage cs, bytes32 channelId)`](#ForceMove-_requireSpecificChallenge-struct-ForceMove-ChannelStorage-bytes32-)
- [`_requireOngoingChallenge(bytes32 channelId)`](#ForceMove-_requireOngoingChallenge-bytes32-)
- [`_requireChannelNotFinalized(bytes32 channelId)`](#ForceMove-_requireChannelNotFinalized-bytes32-)
- [`_hashChannelStorage(struct ForceMove.ChannelStorage channelStorage)`](#ForceMove-_hashChannelStorage-struct-ForceMove-ChannelStorage-)
- [`_getData(bytes32 channelId)`](#ForceMove-_getData-bytes32-)
- [`_matchesHash(struct ForceMove.ChannelStorage cs, bytes32 h)`](#ForceMove-_matchesHash-struct-ForceMove-ChannelStorage-bytes32-)
- [`_hashState(uint256 turnNumRecord, bool isFinal, bytes32 channelId, struct ForceMove.FixedPart fixedPart, bytes appData, bytes32 outcomeHash)`](#ForceMove-_hashState-uint256-bool-bytes32-struct-ForceMove-FixedPart-bytes-bytes32-)
- [`_hashOutcome(bytes outcome)`](#ForceMove-_hashOutcome-bytes-)
- [`_getChannelId(struct ForceMove.FixedPart fixedPart)`](#ForceMove-_getChannelId-struct-ForceMove-FixedPart-)

# Events:
- [`ChallengeRegistered(bytes32 channelId, uint256 turnNunmRecord, uint256 finalizesAt, address challenger, bool isFinal, struct ForceMove.FixedPart fixedPart, struct ForceMoveApp.VariablePart[] variableParts)`](#ForceMove-ChallengeRegistered-bytes32-uint256-uint256-address-bool-struct-ForceMove-FixedPart-struct-ForceMoveApp-VariablePart---)
- [`ChallengeCleared(bytes32 channelId, uint256 newTurnNumRecord)`](#ForceMove-ChallengeCleared-bytes32-uint256-)
- [`Concluded(bytes32 channelId)`](#ForceMove-Concluded-bytes32-)


# Function `getData(bytes32 channelId) → uint48 finalizesAt, uint48 turnNumRecord, uint160 fingerprint` {#ForceMove-getData-bytes32-}
Calls internal method _getData

    


# Function `forceMove(struct ForceMove.FixedPart fixedPart, uint48 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat, struct ForceMove.Signature challengerSig)` {#ForceMove-forceMove-struct-ForceMove-FixedPart-uint48-struct-ForceMoveApp-VariablePart---uint8-struct-ForceMove-Signature---uint8---struct-ForceMove-Signature-}
No description


# Function `respond(address challenger, bool[2] isFinalAB, struct ForceMove.FixedPart fixedPart, struct ForceMoveApp.VariablePart[2] variablePartAB, struct ForceMove.Signature sig)` {#ForceMove-respond-address-bool-2--struct-ForceMove-FixedPart-struct-ForceMoveApp-VariablePart-2--struct-ForceMove-Signature-}
No description


# Function `refute(uint48 refutationStateTurnNum, address challenger, bool[2] isFinalAB, struct ForceMove.FixedPart fixedPart, struct ForceMoveApp.VariablePart[2] variablePartAB, struct ForceMove.Signature refutationStateSig)` {#ForceMove-refute-uint48-address-bool-2--struct-ForceMove-FixedPart-struct-ForceMoveApp-VariablePart-2--struct-ForceMove-Signature-}
No description


# Function `checkpoint(struct ForceMove.FixedPart fixedPart, uint48 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat)` {#ForceMove-checkpoint-struct-ForceMove-FixedPart-uint48-struct-ForceMoveApp-VariablePart---uint8-struct-ForceMove-Signature---uint8---}
No description


# Function `conclude(uint48 largestTurnNum, struct ForceMove.FixedPart fixedPart, bytes32 appPartHash, bytes32 outcomeHash, uint8 numStates, uint8[] whoSignedWhat, struct ForceMove.Signature[] sigs)` {#ForceMove-conclude-uint48-struct-ForceMove-FixedPart-bytes32-bytes32-uint8-uint8---struct-ForceMove-Signature---}
No description


# Function `_requireThatChallengerIsParticipant(bytes32 supportedStateHash, address[] participants, struct ForceMove.Signature challengerSignature) → address challenger` {#ForceMove-_requireThatChallengerIsParticipant-bytes32-address---struct-ForceMove-Signature-}
No description


# Function `_isAddressInArray(address suspect, address[] addresses) → bool` {#ForceMove-_isAddressInArray-address-address---}
No description


# Function `_validSignatures(uint256 largestTurnNum, address[] participants, bytes32[] stateHashes, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat) → bool` {#ForceMove-_validSignatures-uint256-address---bytes32---struct-ForceMove-Signature---uint8---}
No description


# Function `_acceptableWhoSignedWhat(uint8[] whoSignedWhat, uint256 largestTurnNum, uint256 nParticipants, uint256 nStates) → bool` {#ForceMove-_acceptableWhoSignedWhat-uint8---uint256-uint256-uint256-}
No description


# Function `_recoverSigner(bytes32 _d, struct ForceMove.Signature sig) → address` {#ForceMove-_recoverSigner-bytes32-struct-ForceMove-Signature-}
No description


# Function `_requireStateSupportedBy(uint256 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, bytes32 channelId, struct ForceMove.FixedPart fixedPart, struct ForceMove.Signature[] sigs, uint8[] whoSignedWhat) → bytes32` {#ForceMove-_requireStateSupportedBy-uint256-struct-ForceMoveApp-VariablePart---uint8-bytes32-struct-ForceMove-FixedPart-struct-ForceMove-Signature---uint8---}
No description


# Function `_requireValidTransition(uint256 largestTurnNum, struct ForceMoveApp.VariablePart[] variableParts, uint8 isFinalCount, bytes32 channelId, struct ForceMove.FixedPart fixedPart) → bytes32[]` {#ForceMove-_requireValidTransition-uint256-struct-ForceMoveApp-VariablePart---uint8-bytes32-struct-ForceMove-FixedPart-}
No description


# Function `_requireValidTransition(uint256 nParticipants, bool[2] isFinalAB, struct ForceMoveApp.VariablePart[2] ab, uint256 turnNumB, address appDefinition) → bool` {#ForceMove-_requireValidTransition-uint256-bool-2--struct-ForceMoveApp-VariablePart-2--uint256-address-}
No description


# Function `_bytesEqual(bytes left, bytes right) → bool` {#ForceMove-_bytesEqual-bytes-bytes-}
No description


# Function `_clearChallenge(bytes32 channelId, uint256 newTurnNumRecord)` {#ForceMove-_clearChallenge-bytes32-uint256-}
No description


# Function `_requireChannelOpen(bytes32 channelId)` {#ForceMove-_requireChannelOpen-bytes32-}
No description


# Function `_requireMatchingStorage(struct ForceMove.ChannelStorage cs, bytes32 channelId)` {#ForceMove-_requireMatchingStorage-struct-ForceMove-ChannelStorage-bytes32-}
No description


# Function `_requireIncreasedTurnNumber(bytes32 channelId, uint48 newTurnNumRecord)` {#ForceMove-_requireIncreasedTurnNumber-bytes32-uint48-}
No description


# Function `_requireNonDecreasedTurnNumber(bytes32 channelId, uint48 newTurnNumRecord)` {#ForceMove-_requireNonDecreasedTurnNumber-bytes32-uint48-}
No description


# Function `_requireSpecificChallenge(struct ForceMove.ChannelStorage cs, bytes32 channelId)` {#ForceMove-_requireSpecificChallenge-struct-ForceMove-ChannelStorage-bytes32-}
No description


# Function `_requireOngoingChallenge(bytes32 channelId)` {#ForceMove-_requireOngoingChallenge-bytes32-}
No description


# Function `_requireChannelNotFinalized(bytes32 channelId)` {#ForceMove-_requireChannelNotFinalized-bytes32-}
No description


# Function `_hashChannelStorage(struct ForceMove.ChannelStorage channelStorage) → bytes32 newHash` {#ForceMove-_hashChannelStorage-struct-ForceMove-ChannelStorage-}
No description


# Function `_getData(bytes32 channelId) → uint48 turnNumRecord, uint48 finalizesAt, uint160 fingerprint` {#ForceMove-_getData-bytes32-}
No description


# Function `_matchesHash(struct ForceMove.ChannelStorage cs, bytes32 h) → bool` {#ForceMove-_matchesHash-struct-ForceMove-ChannelStorage-bytes32-}
No description


# Function `_hashState(uint256 turnNumRecord, bool isFinal, bytes32 channelId, struct ForceMove.FixedPart fixedPart, bytes appData, bytes32 outcomeHash) → bytes32` {#ForceMove-_hashState-uint256-bool-bytes32-struct-ForceMove-FixedPart-bytes-bytes32-}
No description


# Function `_hashOutcome(bytes outcome) → bytes32` {#ForceMove-_hashOutcome-bytes-}
No description


# Function `_getChannelId(struct ForceMove.FixedPart fixedPart) → bytes32 channelId` {#ForceMove-_getChannelId-struct-ForceMove-FixedPart-}
No description



# Event `ChallengeRegistered(bytes32 channelId, uint256 turnNunmRecord, uint256 finalizesAt, address challenger, bool isFinal, struct ForceMove.FixedPart fixedPart, struct ForceMoveApp.VariablePart[] variableParts)` {#ForceMove-ChallengeRegistered-bytes32-uint256-uint256-address-bool-struct-ForceMove-FixedPart-struct-ForceMoveApp-VariablePart---}
No description


# Event `ChallengeCleared(bytes32 channelId, uint256 newTurnNumRecord)` {#ForceMove-ChallengeCleared-bytes32-uint256-}
No description


# Event `Concluded(bytes32 channelId)` {#ForceMove-Concluded-bytes32-}
No description

