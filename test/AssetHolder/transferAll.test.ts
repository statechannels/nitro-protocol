import {ethers} from 'ethers';
import {expectRevert} from 'magmo-devtools';
// @ts-ignore
import AssetHolderArtifact from '../../build/contracts/TESTAssetHolder.json';
import {setupContracts, newAssetTransferredEvent} from '../test-helpers';
import {defaultAbiCoder, keccak256} from 'ethers/utils';
import {HashZero} from 'ethers/constants';

const provider = new ethers.providers.JsonRpcProvider(
  `http://localhost:${process.env.DEV_GANACHE_PORT}`,
);
const signer0 = provider.getSigner(0); // convention matches setupContracts function
let signer0Address;
let AssetHolder: ethers.Contract;
let assetTransferredEvent;
const chainId = 1234;
const participants = ['', '', ''];

beforeAll(async () => {
  AssetHolder = await setupContracts(provider, AssetHolderArtifact);
  signer0Address = await signer0.getAddress();
});

const description0 = 'Reverts transferAll tx when outcomeHash does not match';
const description1 =
  'Pays ETH out when directly-funded channel affords sufficient ETH for a single external address';

// amounts are valueString represenationa of wei
describe('transferAll', () => {
  it.each`
    description     | channelNonce | held   | affords | amount | outcomeSet | reasonString
    ${description0} | ${0}         | ${'1'} | ${'0'}  | ${'1'} | ${false}   | ${'transferAll | submitted data does not match stored outcomeHash'}
    ${description1} | ${1}         | ${'1'} | ${'1'}  | ${'1'} | ${true}    | ${undefined}
  `('$description', async ({channelNonce, held, affords, amount, outcomeSet, reasonString}) => {
    held = ethers.utils.parseUnits(held, 'wei');
    amount = ethers.utils.parseUnits(amount, 'wei');
    affords = ethers.utils.parseUnits(affords, 'wei');

    // populate participants array (every test run targets a unique channel)
    for (let i = 0; i < 3; i++) {
      participants[i] = ethers.Wallet.createRandom().address;
    }
    // compute channelId
    const channelId = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'address[]', 'uint256'],
        [chainId, participants, channelNonce],
      ),
    );

    // set holdings (only works on test contract)
    if (held > 0) {
      await (await AssetHolder.setHoldings(channelId, held)).wait();
      expect(await AssetHolder.holdings(channelId)).toEqual(held);
    }

    // compute an appropriate allocation
    const allocation = [{destination: signer0Address.padEnd(66, '0'), amount: affords}]; // sufficient
    const allocationBytes = defaultAbiCoder.encode(
      ['tuple(bytes32 destination, uint256 amount)[]'],
      [allocation],
    );
    const labelledAllocationOrGuarantee = [0, allocationBytes];
    const outcomeContent = defaultAbiCoder.encode(
      ['tuple(uint8, bytes)'],
      [labelledAllocationOrGuarantee],
    );
    const outcomeHash = keccak256(outcomeContent);

    // set outcomeHash
    if (outcomeSet) {
      await (await AssetHolder.setOutcomePermissionless(channelId, outcomeHash)).wait();
      expect(await AssetHolder.outcomeHashes(channelId)).toBe(outcomeHash);
    }

    // call method in a slightly different way if expecting a revert
    if (reasonString) {
      const regex = new RegExp(
        '^' + 'VM Exception while processing transaction: revert ' + reasonString + '$',
      );
      await expectRevert(() => AssetHolder.transferAll(channelId, allocationBytes), regex);
    } else {
      // register for events
      assetTransferredEvent = newAssetTransferredEvent(AssetHolder, signer0Address.padEnd(66, '0'));
      // submit tx
      const tx = await AssetHolder.transferAll(channelId, allocationBytes);
      // wait for tx to be mined
      await tx.wait();

      // catch event
      expect(await assetTransferredEvent).toEqual(amount);

      // check new holdings
      expect(await AssetHolder.holdings(channelId)).toEqual(held.sub(affords));

      // check new outcomeHash
      const expectedOutcomeHash = HashZero;
      expect(await AssetHolder.outcomeHashes(channelId)).toEqual(expectedOutcomeHash);
    }
  });
});
