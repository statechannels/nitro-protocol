import {ethers} from 'ethers';
import {expectRevert} from 'magmo-devtools';
// @ts-ignore
import optimizedForceMoveArtifact from '../build/contracts/TESTOptimizedForceMove.json';
import {splitSignature, solidityKeccak256, formatBytes32String} from 'ethers/utils';

let optimizedForceMove: ethers.Contract;

const provider = new ethers.providers.JsonRpcProvider(
  `http://localhost:${process.env.DEV_GANACHE_PORT}`,
);

async function setupContracts() {
  let networkId;
  networkId = (await provider.getNetwork()).chainId;
  const contractAddress = optimizedForceMoveArtifact.networks[networkId].address;
  optimizedForceMove = new ethers.Contract(
    contractAddress,
    optimizedForceMoveArtifact.abi,
    provider,
  );
}

beforeAll(async () => {
  await setupContracts();
});

describe('_isAddressInArray', () => {
  const suspect = ethers.Wallet.createRandom().address;
  let addresses;
  addresses = [
    ethers.Wallet.createRandom().address,
    ethers.Wallet.createRandom().address,
    ethers.Wallet.createRandom().address,
  ];

  it('verifies absence of suspect', async () => {
    expect(await optimizedForceMove.isAddressInArray(suspect, addresses)).toBe(false);
  });
  it('finds an address hiding in an array', async () => {
    addresses[1] = suspect;
    expect(await optimizedForceMove.isAddressInArray(suspect, addresses)).toBe(true);
  });
});

describe('_acceptableWhoSignedWhat', () => {
  let whoSignedWhat;
  let largestTurnNum;
  let nParticipants = 3;
  let nStates;
  it('verifies correct array of who signed what (n states)', async () => {
    whoSignedWhat = [0, 1, 2];
    nParticipants = 3;
    nStates = 3;
    for (largestTurnNum = 2; largestTurnNum < 14; largestTurnNum += nParticipants) {
      expect(
        await optimizedForceMove.acceptableWhoSignedWhat(
          whoSignedWhat,
          largestTurnNum,
          nParticipants,
          nStates,
        ),
      ).toBe(true);
    }
  });
  it('verifies correct array of who signed what (fewer than n states)', async () => {
    whoSignedWhat = [0, 0, 1];
    nStates = 2;
    for (largestTurnNum = 2; largestTurnNum < 14; largestTurnNum += nParticipants) {
      expect(
        await optimizedForceMove.acceptableWhoSignedWhat(
          whoSignedWhat,
          largestTurnNum,
          nParticipants,
          nStates,
        ),
      ).toBe(true);
    }
  });
  it('verifies correct array of who signed what (1 state)', async () => {
    whoSignedWhat = [0, 0, 0];
    nStates = 1;
    for (largestTurnNum = 2; largestTurnNum < 14; largestTurnNum += nParticipants) {
      expect(
        await optimizedForceMove.acceptableWhoSignedWhat(
          whoSignedWhat,
          largestTurnNum,
          nParticipants,
          nStates,
        ),
      ).toBe(true);
    }
  });
  it('reverts when the array is not the required length', async () => {
    whoSignedWhat = [0, 0];
    nStates = 1;
    for (largestTurnNum = 2; largestTurnNum < 14; largestTurnNum += nParticipants) {
      await expectRevert(
        () =>
          optimizedForceMove.acceptableWhoSignedWhat(
            whoSignedWhat,
            largestTurnNum,
            nParticipants,
            nStates,
          ),
        '_validSignatures: whoSignedWhat must be the same length as participants',
      );
    }
  });
  it('returns false when a participant signs a state with an insufficiently large turnNum', async () => {
    whoSignedWhat = [0, 0, 2];
    nStates = 3;
    for (largestTurnNum = 2; largestTurnNum < 14; largestTurnNum += nParticipants) {
      expect(
        await optimizedForceMove.acceptableWhoSignedWhat(
          whoSignedWhat,
          largestTurnNum,
          nParticipants,
          nStates,
        ),
      ).toBe(false);
    }
  });
});

describe('_recoverSigner', () => {
  // following https://docs.ethers.io/ethers.js/html/cookbook-signing.html
  const privateKey = '0x0123456789012345678901234567890123456789012345678901234567890123';
  const wallet = new ethers.Wallet(privateKey);
  const msgHash = ethers.utils.id('Hello World');
  const msgHashBytes = ethers.utils.arrayify(msgHash);
  it('recovers the signer correctly', async () => {
    const sig = splitSignature(await wallet.signMessage(msgHashBytes));
    expect(await optimizedForceMove.recoverSigner(msgHash, sig.v, sig.r, sig.s)).toEqual(
      wallet.address,
    );
  });
});
