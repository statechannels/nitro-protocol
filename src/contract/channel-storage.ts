import {Uint256, Bytes32, Address, Bytes} from './types';
import {defaultAbiCoder, keccak256} from 'ethers/utils';
import {Outcome, hashOutcome} from './outcome';
import {State, hashState} from './state';
import {HashZero, AddressZero} from 'ethers/constants';
import {eqHex} from '../hex-utils';

export interface ChannelStorage {
  largestTurnNum: Uint256;
  finalizesAt: Uint256;
  state?: State;
  challengerAddress?: Address;
  outcome?: Outcome;
}
const CHANNEL_STORAGE_TYPE =
  'tuple(uint256 turnNumRecord, uint256 finalizesAt, bytes32 stateHash, address challengerAddress, bytes32 outcomeHash)';

export interface ChannelStorageLite {
  finalizesAt: Uint256;
  state: State;
  challengerAddress: Address;
  outcome: Outcome;
}
const CHANNEL_STORAGE_LITE_TYPE =
  'tuple(uint256 finalizesAt, bytes32 stateHash, address challengerAddress, bytes32 outcomeHash)';

export function hashChannelStorage(channelStorage: ChannelStorage): Bytes32 {
  return keccak256(encodeChannelStorage(channelStorage));
}

export function encodeChannelStorage({
  finalizesAt,
  state,
  challengerAddress,
  largestTurnNum,
  outcome,
}: ChannelStorage): Bytes {
  /*
  When the channel is not open, it is still possible for the state and
  challengerAddress to be missing. They should either both be present, or
  both be missing, the latter indicating that the channel is finalized.
  It is currently up to the caller to ensure this.
  */
  const isOpen = eqHex(finalizesAt, HashZero);
  const isFinalized = !isOpen && !state;

  if (isOpen && (outcome || state || challengerAddress)) {
    throw new Error(
      `Invalid open channel storage: ${JSON.stringify(outcome || state || challengerAddress)}`,
    );
  }

  const stateHash = isOpen || !state ? HashZero : hashState(state);
  const outcomeHash = isOpen ? HashZero : hashOutcome(outcome);
  challengerAddress = isOpen || isFinalized ? AddressZero : challengerAddress;

  return defaultAbiCoder.encode(
    [CHANNEL_STORAGE_TYPE],
    [[largestTurnNum, finalizesAt, stateHash, challengerAddress, outcomeHash]],
  );
}

export function encodeChannelStorageLite(channelStorageLite: ChannelStorageLite): Bytes {
  const outcomeHash = channelStorageLite.outcome
    ? hashOutcome(channelStorageLite.outcome)
    : HashZero;
  const stateHash = channelStorageLite.state ? hashState(channelStorageLite.state) : HashZero;
  const {finalizesAt, challengerAddress} = channelStorageLite;

  return defaultAbiCoder.encode(
    [CHANNEL_STORAGE_LITE_TYPE],
    [[finalizesAt, stateHash, challengerAddress, outcomeHash]],
  );
}
