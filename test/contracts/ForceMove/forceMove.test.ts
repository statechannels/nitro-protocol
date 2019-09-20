import {ethers} from 'ethers';
import {expectRevert} from 'magmo-devtools';
// @ts-ignore
import ForceMoveArtifact from '../../../build/contracts/TESTForceMove.json';
// @ts-ignore
import countingAppArtifact from '../../../build/contracts/CountingApp.json';
import {defaultAbiCoder, hexlify} from 'ethers/utils';
import {HashZero} from 'ethers/constants';
import {
  setupContracts,
  sign,
  nonParticipant,
  clearedChallengeHash,
  ongoingChallengeHash,
  newChallengeRegisteredEvent,
  sendTransaction,
  signStates,
} from '../../test-helpers';
import {Channel, getChannelId} from '../../../src/contract/channel';
import {State, getVariablePart, getFixedPart} from '../../../src/contract/state';
import {hashChallengeMessage} from '../../../src/contract/challenge';
import {hashChannelStorage, ChannelStorage} from '../../../src/contract/channel-storage';
import {createForceMoveTransaction} from '../../../src/contract/transaction-creators/force-move';
const provider = new ethers.providers.JsonRpcProvider(
  `http://localhost:${process.env.DEV_GANACHE_PORT}`,
);
let ForceMove: ethers.Contract;
let networkId;

const chainId = '0x1234';
const participants = ['', '', ''];
const wallets = new Array(3);
const challengeDuration = 0x1;
const outcome = [{allocation: [], assetHolderAddress: ethers.Wallet.createRandom().address}];

let appDefinition;

// populate wallets and participants array
for (let i = 0; i < 3; i++) {
  wallets[i] = ethers.Wallet.createRandom();
  participants[i] = wallets[i].address;
}
// set event listener
let challengeRegisteredEvent;

beforeAll(async () => {
  ForceMove = await setupContracts(provider, ForceMoveArtifact);
  networkId = (await provider.getNetwork()).chainId;
  appDefinition = countingAppArtifact.networks[networkId].address; // use a fixed appDefinition in all tests
});

// Scenarios are synonymous with channelNonce:

const acceptsWhenOpen = 'It accepts for an open channel, and updates storage correctly, ';
const accepts1 = acceptsWhenOpen + 'when the slot is empty, n states submitted';
const accepts2 = acceptsWhenOpen + 'when the slot is empty, 1 state submitted';
const accepts3 = acceptsWhenOpen + 'when the slot is not empty, n states submitted';
const accepts4 = acceptsWhenOpen + 'when the slot is not empty, 1 state submitted';

const acceptsWhenChallengePresent =
  'It accepts when a challenge is present, and updates storage correctly, ';
const accepts5 = acceptsWhenChallengePresent + 'when the turnNumRecord increases, 1 state';
const accepts6 = acceptsWhenChallengePresent + 'when the turnNumRecord increases, n states';

const revertsWhenOpenIf = 'It reverts for an open channel if ';
const reverts1 = revertsWhenOpenIf + 'the turnNumRecord does not increase';
const reverts2 = revertsWhenOpenIf + 'the challengerSig is incorrect';
const reverts3 = revertsWhenOpenIf + 'the states do not form a validTransition chain';

const reverts4 = 'It reverts when a challenge is present if the turnNumRecord does not increase';
const reverts5 = 'It reverts when the channel is finalized';

describe('forceMove', () => {
  it.each`
    description     | channelNonce | initialChannelStorageHash  | largestTurnNum | appDatas     | isFinalCount | whoSignedWhat | challenger        | reasonString
    ${description1} | ${201}       | ${HashZero}                | ${8}           | ${[0, 1, 2]} | ${0}         | ${[0, 1, 2]}  | ${wallets[2]}     | ${undefined}
    ${description2} | ${202}       | ${HashZero}                | ${8}           | ${[2]}       | ${0}         | ${[0, 0, 0]}  | ${wallets[2]}     | ${undefined}
    ${description3} | ${203}       | ${clearedChallengeHash(5)} | ${8}           | ${[2]}       | ${0}         | ${[0, 0, 0]}  | ${wallets[2]}     | ${undefined}
    ${description4} | ${204}       | ${clearedChallengeHash(5)} | ${2}           | ${[2]}       | ${0}         | ${[0, 0, 0]}  | ${wallets[2]}     | ${'Stale challenge!'}
    ${description5} | ${205}       | ${ongoingChallengeHash(5)} | ${8}           | ${[2]}       | ${0}         | ${[0, 0, 0]}  | ${wallets[2]}     | ${'Channel not open.'}
    ${description6} | ${206}       | ${HashZero}                | ${8}           | ${[0, 1, 2]} | ${0}         | ${[0, 1, 2]}  | ${nonParticipant} | ${'Challenger is not a participant'}
    ${description7} | ${207}       | ${HashZero}                | ${8}           | ${[0, 1, 1]} | ${0}         | ${[0, 1, 2]}  | ${wallets[2]}     | ${'CountingApp: Counter must be incremented'}
  `(
    '$description', // for the purposes of this test, chainId and participants are fixed, making channelId 1-1 with channelNonce
    async ({
      channelNonce,
      initialChannelStorageHash,
      largestTurnNum,
      appDatas,
      isFinalCount,
      whoSignedWhat,
      challenger,
      reasonString,
    }) => {
      const channel: Channel = {
        chainId,
        participants,
        channelNonce,
      };
      const channelId = getChannelId(channel);

      const states: State[] = [];
      for (let i = 0; i < appDatas.length; i++) {
        states.push({
          turnNum: largestTurnNum - appDatas.length + 1 + i,
          isFinal: i > appDatas.length - isFinalCount,
          channel,
          challengeDuration,
          outcome,
          appDefinition,
          appData: defaultAbiCoder.encode(['uint256'], [appDatas[i]]),
        });
      }

      const variableParts = states.map(state => getVariablePart(state));
      const fixedPart = getFixedPart(states[0]);

      // sign the states
      // sign the states
      const sigs = await signStates(states, wallets, whoSignedWhat);
      // compute challengerSig
      const msgHash = hashChallengeMessage({largestTurnNum, channelId});

      const {v, r, s} = await sign(challenger, msgHash);
      const challengerSig = {v, r, s};

      // set current channelStorageHashes value
      await (await ForceMove.setChannelStorageHash(channelId, initialChannelStorageHash)).wait();

      const transactionRequest = createForceMoveTransaction(
        states,
        sigs,
        whoSignedWhat,
        challengerSig,
      );
      // call forceMove in a slightly different way if expecting a revert
      if (reasonString) {
        const regex = new RegExp(
          '^' + 'VM Exception while processing transaction: revert ' + reasonString + '$',
        );

        await expectRevert(() => {
          return sendTransaction(provider, ForceMove.address, transactionRequest);
        }, regex);
      } else {
        challengeRegisteredEvent = newChallengeRegisteredEvent(ForceMove, channelId);

        await sendTransaction(provider, ForceMove.address, transactionRequest);

        // catch ForceMove event
        const [
          eventChannelId,
          eventTurnNumRecord,
          eventFinalizesAt,
          eventChallenger,
          eventIsFinal,
          eventFixedPart,
          eventVariableParts,
        ] = await challengeRegisteredEvent;

        // check this information is enough to respond
        expect(eventChannelId).toEqual(channelId);
        expect(eventTurnNumRecord._hex).toEqual(hexlify(largestTurnNum));
        expect(eventChallenger).toEqual(challenger.address);
        expect(eventFixedPart[0]._hex).toEqual(hexlify(fixedPart.chainId));
        expect(eventFixedPart[1]).toEqual(fixedPart.participants);
        expect(eventFixedPart[2]._hex).toEqual(hexlify(fixedPart.channelNonce));
        expect(eventFixedPart[3]).toEqual(fixedPart.appDefinition);
        expect(eventFixedPart[4]._hex).toEqual(hexlify(fixedPart.challengeDuration));
        expect(eventIsFinal).toEqual(isFinalCount > 0);
        expect(eventVariableParts[eventVariableParts.length - 1][0]).toEqual(
          variableParts[variableParts.length - 1].outcome,
        );
        expect(eventVariableParts[eventVariableParts.length - 1][1]).toEqual(
          variableParts[variableParts.length - 1].appData,
        );

        const expectedChannelStorage: ChannelStorage = {
          turnNumRecord: largestTurnNum,
          finalizesAt: eventFinalizesAt,
          state: states[states.length - 1],
          challengerAddress: challenger.address,
          outcome,
        };
        const expectedChannelStorageHash = hashChannelStorage(expectedChannelStorage);

        // check channelStorageHash against the expected value
        expect(await ForceMove.channelStorageHashes(channelId)).toEqual(expectedChannelStorageHash);
      }
    },
  );
});
