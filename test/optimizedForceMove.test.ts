import {ethers} from 'ethers';
import {expectRevert} from 'magmo-devtools';
// @ts-ignore
import optimizedForceMoveArtifact from '../build/contracts/TESTOptimizedForceMove.json';
// @ts-ignore
import countingAppArtifact from '../build/contracts/CountingApp.json';
import {splitSignature, keccak256, defaultAbiCoder, arrayify} from 'ethers/utils';
import {HashZero} from 'ethers/constants';

let networkId;
let optimizedForceMove: ethers.Contract;
const provider = new ethers.providers.JsonRpcProvider(
  `http://localhost:${process.env.DEV_GANACHE_PORT}`,
);
const signer = provider.getSigner(0);
async function setupContracts() {
  networkId = (await provider.getNetwork()).chainId;
  const optimizedForceMoveContractAddress = optimizedForceMoveArtifact.networks[networkId].address;
  optimizedForceMove = new ethers.Contract(
    optimizedForceMoveContractAddress,
    optimizedForceMoveArtifact.abi,
    signer,
  );
}

beforeAll(async () => {
  await setupContracts();
});

async function sign(wallet: ethers.Wallet, msgHash: string | Uint8Array) {
  // msgHash is a hex string
  // returns an object with v, r, and s properties.
  return splitSignature(await wallet.signMessage(arrayify(msgHash)));
}

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
  const msgHashBytes = arrayify(msgHash);
  it('recovers the signer correctly', async () => {
    const sig = await sign(wallet, msgHashBytes);
    expect(await optimizedForceMove.recoverSigner(msgHash, sig.v, sig.r, sig.s)).toEqual(
      wallet.address,
    );
  });
});

describe('_validSignatures', () => {
  const participants = [];
  let stateHash;
  const stateHashes = [];
  let wallet;
  let sig;
  const sigs = [];
  let brokenSigs;
  const whoSignedWhat = [];
  const largestTurnNum = 2;
  it('returns true (false) for a correct (incorrect) set of signatures on n states', async () => {
    for (let i = 0; i < 3; i++) {
      wallet = ethers.Wallet.createRandom();
      participants[i] = wallet.address;
      stateHash = ethers.utils.id('Commitment' + i);
      stateHashes[i] = stateHash;
      sig = await sign(wallet, stateHash);
      sigs[i] = {v: sig.v, r: sig.r, s: sig.s};
      whoSignedWhat[i] = i;
    }
    expect(
      await optimizedForceMove.validSignatures(
        largestTurnNum,
        participants,
        stateHashes,
        sigs,
        whoSignedWhat,
      ),
    ).toBe(true);
    brokenSigs = sigs.reverse();
    expect(
      await optimizedForceMove.validSignatures(
        largestTurnNum,
        participants,
        stateHashes,
        brokenSigs,
        whoSignedWhat,
      ),
    ).toBe(false);
  });
  it('returns true (false) for a correct (incorrect) set of signatures on 1 state', async () => {
    stateHash = ethers.utils.id('Commitment' + largestTurnNum);
    for (let i = 0; i < 3; i++) {
      wallet = ethers.Wallet.createRandom();
      participants[i] = wallet.address;
      sig = await sign(wallet, stateHash);
      sigs[i] = {v: sig.v, r: sig.r, s: sig.s};
      whoSignedWhat[i] = 0;
    }
    expect(
      await optimizedForceMove.validSignatures(
        largestTurnNum,
        participants,
        [stateHash],
        sigs,
        whoSignedWhat,
      ),
    ).toBe(true);
    brokenSigs = sigs.reverse();
    expect(
      await optimizedForceMove.validSignatures(
        largestTurnNum,
        participants,
        [stateHash],
        brokenSigs,
        whoSignedWhat,
      ),
    ).toBe(false);
  });
});

describe('forceMove', () => {
  // construct data for forceMove parameters
  const chainId = 1234;
  let channelNonce;
  let channelId;
  const turnNumRecord = 0;
  const wallets = [];
  const participants = ['', '', ''];
  const sigs = [, ,];
  let variableParts;
  let stateHashes;

  // populate wallets and participants array
  for (let i = 0; i < 3; i++) {
    wallets[i] = ethers.Wallet.createRandom();
    participants[i] = wallets[i].address;
  }

  let challengerSig;
  let sig;
  let tx;
  it('accepts a valid forceMove tx and updates channelStorageHashes correctly (n states)', async () => {
    // channelId
    channelNonce = 1;
    channelId = keccak256(
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
      appDefinition: countingAppArtifact.networks[networkId].address,
      challengeDuration: 1,
    };

    // compute stateHashes for a chain of 3 non-final states with turnNum = [6,7,8]
    const largestTurnNum = 8;
    const isFinalCount = 0;
    const whoSignedWhat = [0, 1, 2];
    let state;
    let outcomeHash;
    stateHashes = [, ,];
    variableParts = [, ,];
    for (let i = 0; i < 3; i++) {
      const outcome = ethers.utils.id('some outcome data' + i);
      outcomeHash = keccak256(defaultAbiCoder.encode(['bytes'], [outcome]));
      variableParts[i] = {
        outcome,
        appData: ethers.utils.id('some app data' + i),
      };

      const appPartHash = keccak256(
        defaultAbiCoder.encode(
          ['uint256', 'address', 'bytes'],
          [fixedPart.challengeDuration, fixedPart.appDefinition, variableParts[i].appData],
        ),
      );
      state = {
        turnNum: i + 6,
        isFinal: false,
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
    for (let i = 0; i < 3; i++) {
      sig = await sign(wallets[i], stateHashes[i]);
      sigs[i] = {v: sig.v, r: sig.r, s: sig.s};
    }

    // compute challengerSig
    const msgHash = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'bytes32', 'string'],
        [largestTurnNum, channelId, 'forceMove'],
      ),
    );
    const {v, r, s} = await sign(wallets[2], msgHash);
    challengerSig = {v, r, s};

    // inspect current channelStorageHashes value
    const currentHash = await optimizedForceMove.channelStorageHashes(channelId);
    expect(currentHash).toEqual(HashZero);

    // call forceMove
    tx = await optimizedForceMove.forceMove(
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

    // catch ForceMove event and peel-off the expiryTime
    const forceMoveEvent = new Promise((resolve, reject) => {
      optimizedForceMove.on('ForceMove', (cId, expTime, event) => {
        event.removeListener();
        resolve(expTime);
      });
      setTimeout(() => {
        reject(new Error('timeout'));
      }, 60000);
    });
    const expiryTime = await forceMoveEvent;

    // compute expected ChannelStorageHash
    const expectedChannelStorage = [
      largestTurnNum,
      expiryTime,
      stateHashes[2],
      participants[2],
      outcomeHash,
    ];
    const expectedChannelStorageHash = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'uint256', 'bytes32', 'address', 'bytes32'],
        expectedChannelStorage,
      ),
    );

    // call out to public mapping and check channelStorageHash against the expected value
    expect(await optimizedForceMove.channelStorageHashes(channelId)).toEqual(
      expectedChannelStorageHash,
    );
  });
  it('accepts a valid forceMove tx and updates channelStorageHashes correctly (1 state)', async () => {
    // channelId
    channelNonce = 2;
    channelId = keccak256(
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
      appDefinition: countingAppArtifact.networks[networkId].address,
      challengeDuration: 1,
    };

    // compute stateHashes for a single non-final state with turnNum = 8
    const largestTurnNum = 8;
    const isFinalCount = 0;
    const whoSignedWhat = [0, 0, 0];
    let state;
    let outcomeHash;
    const outcome = ethers.utils.id('some outcome data');
    outcomeHash = keccak256(defaultAbiCoder.encode(['bytes'], [outcome]));
    variableParts = [
      {
        outcome,
        appData: ethers.utils.id('some app data'),
      },
    ];

    const appPartHash = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'address', 'bytes'],
        [fixedPart.challengeDuration, fixedPart.appDefinition, variableParts[0].appData],
      ),
    );
    state = {
      turnNum: largestTurnNum,
      isFinal: false,
      channelId,
      appPartHash,
      outcomeHash,
    };
    stateHashes = [
      keccak256(
        defaultAbiCoder.encode(
          [
            'tuple(uint256 turnNum, bool isFinal, bytes32 channelId, bytes32 appPartHash, bytes32 outcomeHash)',
          ],
          [state],
        ),
      ),
    ];

    // sign the states
    for (let i = 0; i < 3; i++) {
      sig = await sign(wallets[i], stateHashes[0]); // everyone signs the same state
      sigs[i] = {v: sig.v, r: sig.r, s: sig.s};
    }

    // compute challengerSig
    const msgHash = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'bytes32', 'string'],
        [largestTurnNum, channelId, 'forceMove'],
      ),
    );
    const {v, r, s} = await sign(wallets[2], msgHash);
    challengerSig = {v, r, s};

    // inspect current channelStorageHashes value
    const currentHash = await optimizedForceMove.channelStorageHashes(channelId);
    expect(currentHash).toEqual(HashZero);

    // call forceMove
    tx = await optimizedForceMove.forceMove(
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

    // catch ForceMove event and peel-off the expiryTime
    const forceMoveEvent = new Promise((resolve, reject) => {
      optimizedForceMove.on('ForceMove', (cId, expTime, event) => {
        event.removeListener();
        resolve(expTime);
      });
      setTimeout(() => {
        reject(new Error('timeout'));
      }, 60000);
    });
    const expiryTime = await forceMoveEvent;

    // compute expected ChannelStorageHash
    const expectedChannelStorage = [
      largestTurnNum,
      expiryTime,
      stateHashes[0],
      participants[2],
      outcomeHash,
    ];
    const expectedChannelStorageHash = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'uint256', 'bytes32', 'address', 'bytes32'],
        expectedChannelStorage,
      ),
    );

    // call out to public mapping and check channelStorageHash against the expected value
    expect(await optimizedForceMove.channelStorageHashes(channelId)).toEqual(
      expectedChannelStorageHash,
    );
  });
});
