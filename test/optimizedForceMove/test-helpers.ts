import {ethers} from 'ethers';
import {splitSignature, arrayify, keccak256, defaultAbiCoder} from 'ethers/utils';
import {HashZero, AddressZero} from 'ethers/constants';

const eventEmitterTimeout = 1200000; // ms

export async function setupContracts(
  provider: ethers.providers.JsonRpcProvider,
  artifact,
  signerIndex: number,
) {
  const networkId = (await provider.getNetwork()).chainId;
  const accounts = await provider.listAccounts();
  const signer = provider.getSigner(accounts[signerIndex]);
  const contractAddress = artifact.networks[networkId].address;
  const contract = new ethers.Contract(contractAddress, artifact.abi, signer);
  return contract;
}

export async function sign(wallet: ethers.Wallet, msgHash: string | Uint8Array) {
  // msgHash is a hex string
  // returns an object with v, r, and s properties.
  return splitSignature(await wallet.signMessage(arrayify(msgHash)));
}

export const nonParticipant = ethers.Wallet.createRandom();

export const clearedChallengeHash = (turnNumRecord: number = 5) => {
  return keccak256(
    defaultAbiCoder.encode(
      ['uint256', 'uint256', 'bytes32', 'address', 'bytes32'],
      [turnNumRecord, 0, HashZero, AddressZero, HashZero], // turnNum = 5
    ),
  );
};

export const ongoingChallengeHash = (turnNumRecord: number = 5) => {
  return keccak256(
    defaultAbiCoder.encode(
      ['uint256', 'uint256', 'bytes32', 'address', 'bytes32'],
      [turnNumRecord, 1e9, HashZero, AddressZero, HashZero], // turnNum = 5, not yet finalized
    ),
  );
};

export const finalizedOutcomeHash = (turnNumRecord: number = 5) => {
  return keccak256(
    defaultAbiCoder.encode(
      ['uint256', 'uint256', 'bytes32', 'address', 'bytes32'],
      [turnNumRecord, 1, HashZero, AddressZero, HashZero], // finalizes at 1, earliest possible
      // the final two fields should also not be zero
    ),
  );
};

export const newForceMoveEvent = (contract: ethers.Contract, channelId: string) => {
  const filter = contract.filters.ForceMove(channelId);
  return new Promise((resolve, reject) => {
    contract.on(
      filter,
      (
        eventChannelIdArg,
        eventTurnNumRecordArg,
        eventFinalizesAtArg,
        eventChallengerArg,
        eventIsFinalArg,
        eventFixedPartArg,
        eventChallengeVariablePartArg,
        event,
      ) => {
        contract.removeAllListeners(filter);
        resolve([
          eventChannelIdArg,
          eventTurnNumRecordArg,
          eventFinalizesAtArg,
          eventChallengerArg,
          eventIsFinalArg,
          eventFixedPartArg,
          eventChallengeVariablePartArg,
        ]);
      },
    );
    /*setTimeout(() => {
      reject(new Error('timeout'));
    }, eventEmitterTimeout);*/
  });
};

export const newChallengeClearedEvent = (contract: ethers.Contract, channelId: string) => {
  const filter = contract.filters.ChallengeCleared(channelId);
  return new Promise((resolve, reject) => {
    contract.on(filter, (eventChannelId, eventTurnNumRecord, event) => {
      // match event for this channel only
      contract.removeAllListeners(filter);
      resolve([eventChannelId, eventTurnNumRecord]);
    });
    /*setTimeout(() => {
      reject(new Error('timeout'));
    }, eventEmitterTimeout);*/
  });
};

export const newConcludedEvent = (contract: ethers.Contract, channelId: string) => {
  const filter = contract.filters.Concluded(channelId);
  return new Promise((resolve, reject) => {
    contract.on(filter, (eventChannelId, event) => {
      // match event for this channel only
      contract.removeAllListeners(filter);
      resolve([channelId]);
    });
    /*setTimeout(() => {
      reject(new Error('timeout'));
    }, eventEmitterTimeout);*/
  });
};
