import {ethers} from 'ethers';
// @ts-ignore
import optimizedForceMoveArtifact from '../../build/contracts/TESTOptimizedForceMove.json';
// @ts-ignore
import countingAppArtifact from '../../build/contracts/CountingApp.json';
import {splitSignature, keccak256, defaultAbiCoder, arrayify} from 'ethers/utils';

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
const chainId = 1234;
const participants = ['', '', ''];
const wallets = new Array(3);

// populate wallets and participants array
for (let i = 0; i < 3; i++) {
  wallets[i] = ethers.Wallet.createRandom();
  participants[i] = wallets[i].address;
}

beforeAll(async () => {
  await setupContracts();
});

async function sign(wallet: ethers.Wallet, msgHash: string | Uint8Array) {
  // msgHash is a hex string
  // returns an object with v, r, and s properties.
  return splitSignature(await wallet.signMessage(arrayify(msgHash)));
}

describe('respond', () => {
  const existingTurnNumRecord = 8;
  const challengeDuration = 1000;
  const isFinalAB = [false, false];
  const challenger = participants[existingTurnNumRecord % participants.length];

  const outcome = ethers.utils.id('some outcome data');
  const outcomeHash = keccak256(defaultAbiCoder.encode(['bytes'], [outcome]));

  const challengeVariablePart = {
    outcome,
    appData: defaultAbiCoder.encode(['uint256'], [1]), // a counter
  };
  const responseVariablePart = {
    outcome,
    appData: defaultAbiCoder.encode(['uint256'], [2]), // a counter
  };

  it('accepts a valid respond tx and clears an existing challenge', async () => {
    const blockNumber = await provider.getBlockNumber();
    const blockTimestamp = (await provider.getBlock(blockNumber)).timestamp;
    const expiryTime = blockTimestamp + challengeDuration;

    // channelId
    const channelNonce = 1;
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
      appDefinition: countingAppArtifact.networks[networkId].address,
      challengeDuration,
    };

    const challengeAppPartHash = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'address', 'bytes'],
        [fixedPart.challengeDuration, fixedPart.appDefinition, challengeVariablePart.appData],
      ),
    );

    const challengeState = {
      turnNum: existingTurnNumRecord,
      isFinal: false,
      channelId,
      challengeAppPartHash,
      outcomeHash,
    };

    const challengeStateHash = keccak256(
      defaultAbiCoder.encode(
        [
          'tuple(uint256 turnNum, bool isFinal, bytes32 channelId, bytes32 challengeAppPartHash, bytes32 outcomeHash)',
        ],
        [challengeState],
      ),
    );

    const responseAppPartHash = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'address', 'bytes'],
        [challengeDuration, fixedPart.appDefinition, responseVariablePart.appData],
      ),
    );

    const responseState = {
      turnNum: existingTurnNumRecord + 1,
      isFinal: false,
      channelId,
      responseAppPartHash,
      outcomeHash,
    };

    const responseStateHash = keccak256(
      defaultAbiCoder.encode(
        [
          'tuple(uint256 turnNum, bool isFinal, bytes32 channelId, bytes32 responseAppPartHash, bytes32 outcomeHash)',
        ],
        [responseState],
      ),
    );

    // compute expected ChannelStorageHash
    const expectedChannelStorage = [
      existingTurnNumRecord,
      expiryTime,
      challengeStateHash,
      participants[2],
      outcomeHash,
    ];
    const expectedChannelStorageHash = keccak256(
      defaultAbiCoder.encode(
        ['uint256', 'uint256', 'bytes32', 'address', 'bytes32'],
        expectedChannelStorage,
      ),
    );

    // call public wrapper to set state (only works on test contract)
    const tx = await optimizedForceMove.setChannelStorageHash(channelId, expectedChannelStorage);
    await tx.wait();
    expect(await optimizedForceMove.channelStorageHashes(channelId)).toEqual(
      expectedChannelStorageHash,
    );

    // sign the state
    const signature = await sign(
      wallets[(existingTurnNumRecord + 1) % participants.length],
      responseStateHash,
    );
    const sig = {v: signature.v, r: signature.r, s: signature.s};

    // call forceMove
    const tx2 = await optimizedForceMove.respond(
      existingTurnNumRecord,
      expiryTime,
      challenger,
      isFinalAB,
      fixedPart,
      [challengeVariablePart, responseVariablePart],
      sig,
    );
  });
});
