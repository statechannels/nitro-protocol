import {ethers} from 'ethers';
// @ts-ignore
import NitroAdjudicatorArtifact from '../../build/contracts/TESTNitroAdjudicator.json';
// @ts-ignore
import ETHAssetHolderArtifact from '../../build/contracts/ETHAssetHolder.json';
// @ts-ignore
import countingAppArtifact from '../../build/contracts/CountingApp.json';

import {keccak256, defaultAbiCoder, toUtf8Bytes} from 'ethers/utils';
import {AddressZero} from 'ethers/constants';
import {setupContracts, finalizedOutcomeHash} from '../test-helpers';
import {expectRevert} from 'magmo-devtools';

const provider = new ethers.providers.JsonRpcProvider(
  `http://localhost:${process.env.DEV_GANACHE_PORT}`,
);
let NitroAdjudicator: ethers.Contract;
let ETHAssetHolder: ethers.Contract;
let networkId;

// constants for this test suite
const challengerAddress = AddressZero;
const finalizesAt = 1; // seconds after genesis block
const chainId = 1234;
const participants = ['', '', ''];
const wallets = new Array(3);
const outcome = toUtf8Bytes('some outcome data'); // use a fixed outcome for all state updates in all tests
const outcomeHash = keccak256(defaultAbiCoder.encode(['bytes'], [outcome]));
const stateHash = keccak256(defaultAbiCoder.encode(['bytes'], [toUtf8Bytes('mocked state data')]));
let appDefinition;

// populate wallets and participants array
for (let i = 0; i < 3; i++) {
  wallets[i] = ethers.Wallet.createRandom();
  participants[i] = wallets[i].address;
}

beforeAll(async () => {
  NitroAdjudicator = await setupContracts(provider, NitroAdjudicatorArtifact);
  ETHAssetHolder = await setupContracts(provider, ETHAssetHolderArtifact);
  networkId = (await provider.getNetwork()).chainId;
  appDefinition = countingAppArtifact.networks[networkId].address; // use a fixed appDefinition in all tests
});

// Scenarios are synonymous with channelNonce:

const description1 =
  'NitroAdjudicator accepts a pushOutcome tx for a finalized channel, and AssetHolder storage updated correctly';

describe('forceMove', () => {
  it.each`
    description     | channelNonce | declaredTurnNumRecord | initialChannelStorageHash                                                          | reasonString
    ${description1} | ${1101}      | ${5}                  | ${finalizedOutcomeHash(5, finalizesAt, stateHash, challengerAddress, outcomeHash)} | ${undefined}
  `(
    '$description', // for the purposes of this test, chainId and participants are fixed, making channelId 1-1 with channelNonce
    async ({channelNonce, declaredTurnNumRecord, initialChannelStorageHash, reasonString}) => {
      // compute channelId
      const channelId = keccak256(
        defaultAbiCoder.encode(
          ['uint256', 'address[]', 'uint256'],
          [chainId, participants, channelNonce],
        ),
      );

      // call public wrapper to set state (only works on test contract)
      const tx = await NitroAdjudicator.setChannelStorageHash(channelId, initialChannelStorageHash);
      await tx.wait();
      expect(await NitroAdjudicator.channelStorageHashes(channelId)).toEqual(
        initialChannelStorageHash,
      );

      // call method in a slightly different way if expecting a revert
      if (reasonString) {
        const regex = new RegExp(
          '^' + 'VM Exception while processing transaction: revert ' + reasonString + '$',
        );
        await expectRevert(
          () =>
            NitroAdjudicator.pushOutcome(
              channelId,
              declaredTurnNumRecord,
              finalizesAt,
              stateHash,
              challengerAddress,
              outcome,
              ETHAssetHolder.address,
            ),
          regex,
        );
      } else {
        const tx2 = await NitroAdjudicator.pushOutcome(
          channelId,
          declaredTurnNumRecord,
          finalizesAt,
          stateHash,
          challengerAddress,
          outcome,
          ETHAssetHolder.address,
        );
        // wait for tx to be mined
        await tx2.wait();

        // check AssetHolder storage against the expected value
        expect(await ETHAssetHolder.outcomeHashes(channelId)).toEqual(outcomeHash);
      }
    },
  );
});
