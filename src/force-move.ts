// @ts-ignore
import ForceMoveArtifact from '../build/contracts/ForceMove.json';
import * as ethers from 'ethers';
import {TransactionRequest} from 'ethers/providers';
import {State, hashState, getVariablePart, getFixedPart} from './state';

// TODO: Currently we are setting some arbitrary gas limit
// to avoid issues with Ganache sendTransaction and parsing BN.js
// If we don't set a gas limit some transactions will fail
const GAS_LIMIT = 3000000;

const ForceMoveContractInterface = new ethers.utils.Interface(ForceMoveArtifact.abi);

// function refute(
//     uint256 turnNumRecord,
//     uint256 refutationStateTurnNum,
//     uint256 finalizesAt,
//     address challenger,
//     bool[2] memory isFinalAB,
//     FixedPart memory fixedPart,
//     ForceMoveApp.VariablePart[2] memory variablePartAB,
//     // variablePartAB[0] = challengeVariablePart
//     // variablePartAB[1] = refutationVariablePart
//     Signature memory refutationStateSig

export function createRefuteTransaction(
  turnNumRecord: number,
  finalizesAt: string,
  challengeState: State,
  refuteState: State,
  refutationStateSignature: ethers.utils.Signature,
): TransactionRequest {
  const {participants} = challengeState.channel;
  const variablePartAB = [getVariablePart(challengeState), getVariablePart(refuteState)];
  const fixedPart = getFixedPart(refuteState);
  const isFinalAB = [challengeState.isFinal, refuteState.isFinal];
  // TODO: Can we still assume that we can rely on turnNum to figure out who authored the state?
  const challenger = participants[challengeState.turnNum % participants.length];
  const refutationStateTurnNum = refuteState.turnNum;

  const data = ForceMoveContractInterface.functions.refute.encode([
    turnNumRecord,
    refutationStateTurnNum,
    finalizesAt,
    challenger,
    isFinalAB,
    fixedPart,
    variablePartAB,
    refutationStateSignature,
  ]);
  return {data, gasLimit: GAS_LIMIT};
}

export function createForceMoveTransaction(
  turnNumRecord: number,
  states: State[],
  signatures: ethers.utils.Signature[],
  whoSignedWhat: number[],
  challengerSignature: ethers.utils.Signature,
): TransactionRequest {
  // Sanity checks on expected lengths
  if (states.length === 0) {
    throw new Error('No states provided');
  }
  const {participants} = states[0].channel;
  if (participants.length !== signatures.length) {
    throw new Error(
      `Participants (length:${participants.length}) and signatures (length:${signatures.length}) need to be the same length`,
    );
  }

  const stateHashes = states.map(s => hashState(s));
  const variableParts = states.map(s => getVariablePart(s));
  const fixedPart = getFixedPart(states[0]);

  // Get the largest turn number from the states
  const largestTurnNum = Math.max(...states.map(s => s.turnNum));
  const isFinalCount = states.filter(s => s.isFinal === true).length;

  const data = ForceMoveContractInterface.functions.forceMove.encode([
    turnNumRecord,
    fixedPart,
    largestTurnNum,
    variableParts,
    isFinalCount,
    signatures,
    whoSignedWhat,
    challengerSignature,
  ]);
  return {data, gasLimit: GAS_LIMIT};
}
