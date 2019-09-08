import {ethers} from 'ethers';
import {expectRevert} from 'magmo-devtools';
// @ts-ignore
import ForceMoveArtifact from '../../build/contracts/TESTForceMove.json';
// @ts-ignore
import countingAppArtifact from '../../build/contracts/CountingApp.json';
import {keccak256, defaultAbiCoder, hexlify} from 'ethers/utils';
import {HashZero} from 'ethers/constants';
import {
  setupContracts,
  sign,
  nonParticipant,
  clearedChallengeHash,
  ongoingChallengeHash,
  newForceMoveEvent,
} from '../test-helpers';

const provider = new ethers.providers.JsonRpcProvider(
  `http://localhost:${process.env.DEV_GANACHE_PORT}`,
);
let ForceMove: ethers.Contract;
let networkId;

const chainId = 1234;
const participants = ['', '', ''];
const wallets = new Array(3);
const challengeDuration = 1;
const outcome = ethers.utils.id('some outcome data'); // use a fixed outcome for all state updates in all tests
const outcomeHash = keccak256(defaultAbiCoder.encode(['bytes'], [outcome]));
let appDefinition;

// populate wallets and participants array
for (let i = 0; i < 3; i++) {
  wallets[i] = ethers.Wallet.createRandom();
  participants[i] = wallets[i].address;
}
// set event listener
let forceMoveEvent;

beforeAll(async () => {
  ForceMove = await setupContracts(provider, ForceMoveArtifact);
  networkId = (await provider.getNetwork()).chainId;
  appDefinition = countingAppArtifact.networks[networkId].address; // use a fixed appDefinition in all tests
});

// Scenarios are synonymous with channelNonce:

const description1 =
  'It accepts a forceMove for an open channel (first challenge, n states submitted), and updates storage correctly';
const description2 =
  'It accepts a forceMove for an open channel (first challenge, 1 state submitted), and updates storage correctly';
const description3 =
  'It accepts a forceMove for an open channel (subsequent challenge, higher turnNum), and updates storage correctly';
const description4 =
  'It reverts a forceMove for an open channel if the turnNum is too small (subsequent challenge, turnNumRecord would decrease)';
const description5 = 'It reverts a forceMove when a challenge is underway / finalized';
const description6 = 'It reverts a forceMove with an incorrect challengerSig';
const description7 = 'It reverts a forceMove when the states do not form a validTransition chain';
const description8 = 'It reverts when an unacceptable whoSignedWhat array is submitted';

describe('forceMove', () => {
  it.each`
    description     | channelNonce | initialChannelStorageHash  | turnNumRecord | largestTurnNum | appDatas     | isFinalCount | whoSignedWhat | challenger        | reasonString
    ${description1} | ${201}       | ${HashZero}                | ${0}          | ${8}           | ${[0, 1, 2]} | ${0}         | ${[0, 1, 2]}  | ${wallets[2]}     | ${undefined}
    ${description2} | ${202}       | ${HashZero}                | ${0}          | ${8}           | ${[2]}       | ${0}         | ${[0, 0, 0]}  | ${wallets[2]}     | ${undefined}
    ${description3} | ${203}       | ${clearedChallengeHash(5)} | ${5}          | ${8}           | ${[2]}       | ${0}         | ${[0, 0, 0]}  | ${wallets[2]}     | ${undefined}
    ${description4} | ${204}       | ${clearedChallengeHash(5)} | ${5}          | ${2}           | ${[2]}       | ${0}         | ${[0, 0, 0]}  | ${wallets[2]}     | ${'Stale challenge!'}
    ${description5} | ${205}       | ${ongoingChallengeHash(5)} | ${5}          | ${8}           | ${[2]}       | ${0}         | ${[0, 0, 0]}  | ${wallets[2]}     | ${'Channel is not open or turnNum does not match'}
    ${description6} | ${206}       | ${HashZero}                | ${0}          | ${8}           | ${[0, 1, 2]} | ${0}         | ${[0, 1, 2]}  | ${nonParticipant} | ${'Challenger is not a participant'}
    ${description7} | ${207}       | ${HashZero}                | ${0}          | ${8}           | ${[0, 1, 1]} | ${0}         | ${[0, 1, 2]}  | ${wallets[2]}     | ${'CountingApp: Counter must be incremented'}
    ${description8} | ${208}       | ${HashZero}                | ${0}          | ${8}           | ${[0, 1, 2]} | ${0}         | ${[0, 0, 2]}  | ${wallets[2]}     | ${'Unacceptable whoSignedWhat array'}
  `(
    '$description', // for the purposes of this test, chainId and participants are fixed, making channelId 1-1 with channelNonce
    async ({
      channelNonce,
      initialChannelStorageHash,
      turnNumRecord,
      largestTurnNum,
      appDatas,
      isFinalCount,
      whoSignedWhat,
      challenger,
      reasonString,
    }) => {
      // compute channelId
      const channelId = keccak256(
        defaultAbiCoder.encode(
          ['uint256', 'address[]', 'uint256'],
          [chainId, participants, channelNonce],
        ),
      );
      // fixedPart
      const fixedPart = {
        chainId,
        participants,
        channelNonce,
        appDefinition,
        challengeDuration,
      };

      // compute stateHashes
      const variableParts = new Array(appDatas.length);
      const stateHashes = new Array(appDatas.length);
      for (let i = 0; i < appDatas.length; i++) {
        variableParts[i] = {
          outcome, // fixed
          appData: defaultAbiCoder.encode(['uint256'], [appDatas[i]]),
        };
        const appPartHash = keccak256(
          defaultAbiCoder.encode(
            ['uint256', 'address', 'bytes'],
            [challengeDuration, appDefinition, defaultAbiCoder.encode(['uint256'], [appDatas[i]])],
          ),
        );
        const state = {
          turnNum: largestTurnNum - appDatas.length + 1 + i,
          isFinal: i > appDatas.length - isFinalCount,
          channelId,
          appPartHash,
          outcomeHash,
        };
        stateHashes[i] = keccak256(
          defaultAbiCoder.encode(
            [
              'tuple(uint256 turnNum, bool isFinal, bytes32 channelId, bytes32 appPartHash, bytes32 outcomeHash)',
            ],
            [state],
          ),
        );
      }

      // sign the states
      const sigs = new Array(stateHashes.length);
      for (let i = 0; i < stateHashes.length; i++) {
        const sig = await sign(wallets[i], stateHashes[whoSignedWhat[i]]);
        sigs[i] = {v: sig.v, r: sig.r, s: sig.s};
      }

      // compute challengerSig
      const msgHash = keccak256(
        defaultAbiCoder.encode(
          ['uint256', 'bytes32', 'string'],
          [largestTurnNum, channelId, 'forceMove'],
        ),
      );
      const {v, r, s} = await sign(challenger, msgHash);
      const challengerSig = {v, r, s};

      // set current channelStorageHashes value
      await (await ForceMove.setChannelStorageHash(channelId, initialChannelStorageHash)).wait();

      // call forceMove in a slightly different way if expecting a revert
      if (reasonString) {
        const regex = new RegExp(
          '^' + 'VM Exception while processing transaction: revert ' + reasonString + '$',
        );
        await expectRevert(
          () =>
            ForceMove.forceMove(
              turnNumRecord,
              fixedPart,
              largestTurnNum,
              variableParts,
              isFinalCount,
              sigs,
              whoSignedWhat,
              challengerSig,
            ),
          regex,
        );
      } else {
        forceMoveEvent = newForceMoveEvent(ForceMove, channelId);
        const tx = await ForceMove.forceMove(
          turnNumRecord,
          fixedPart,
          largestTurnNum,
          variableParts,
          isFinalCount,
          sigs,
          whoSignedWhat,
          challengerSig,
        );
        // wait for tx to be mined
        await tx.wait();

        // catch ForceMove event
        const [
          eventChannelId,
          eventTurnNumRecord,
          eventFinalizesAt,
          eventChallenger,
          eventIsFinal,
          eventFixedPart,
          eventVariableParts,
        ] = await forceMoveEvent;

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

        // compute expected ChannelStorageHash
        const expectedChannelStorage = [
          largestTurnNum,
          eventFinalizesAt,
          stateHashes[stateHashes.length - 1],
          challenger.address,
          outcomeHash,
        ];
        const expectedChannelStorageHash = keccak256(
          defaultAbiCoder.encode(
            ['uint256', 'uint256', 'bytes32', 'address', 'bytes32'],
            expectedChannelStorage,
          ),
        );

        // check channelStorageHash against the expected value
        expect(await ForceMove.channelStorageHashes(channelId)).toEqual(expectedChannelStorageHash);
      }
    },
  );
});
