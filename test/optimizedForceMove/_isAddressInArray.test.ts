import {ethers} from 'ethers';
// @ts-ignore
import OptimizedForceMoveArtifact from '../../build/contracts/TESTOptimizedForceMove.json';
import {setupContracts} from './test-helpers';

const provider = new ethers.providers.JsonRpcProvider(
  `http://localhost:${process.env.DEV_GANACHE_PORT}`,
);
let OptimizedForceMove: ethers.Contract;

const participants = ['', '', ''];
const wallets = new Array(3);

// populate wallets and participants array
for (let i = 0; i < 3; i++) {
  wallets[i] = ethers.Wallet.createRandom();
  participants[i] = wallets[i].address;
}

beforeAll(async () => {
  OptimizedForceMove = await setupContracts(provider, OptimizedForceMoveArtifact, 8);
});

describe('_isAddressInArray', () => {
  let suspect;
  let addresses;

  beforeAll(() => {
    suspect = ethers.Wallet.createRandom().address;
    addresses = [
      ethers.Wallet.createRandom().address,
      ethers.Wallet.createRandom().address,
      ethers.Wallet.createRandom().address,
    ];
  });

  it('verifies absence of suspect', async () => {
    expect(await OptimizedForceMove.isAddressInArray(suspect, addresses)).toBe(false);
  });
  it('finds an address hiding in an array', async () => {
    addresses[1] = suspect;
    expect(await OptimizedForceMove.isAddressInArray(suspect, addresses)).toBe(true);
  });
});
