import * as ethers from 'ethers';
import {
  channelID as getChannelID,
  CountingCommitment,
  countingCommitmentAsCoreCommitment,
  sign,
  Channel,
  CountingApp,
  Address,
  asEthersObject,
  fromParameters,
} from '../src';
import {AddressZero} from 'ethers/constants';
import {BigNumber, bigNumberify} from 'ethers/utils';
import {expectEvent, expectRevert} from 'magmo-devtools';

// @ts-ignore
import NitroAdjudicatorArtifact from '../build/contracts/TestNitroAdjudicator.json';
// @ts-ignore
import NitroLibraryArtifact from '../build/contracts/NitroLibrary.json';

jest.setTimeout(20000);
let nitroAdjudicator: ethers.Contract;
let nitroLibrary: ethers.Contract;
const DEPOSIT_AMOUNT = ethers.utils.parseEther('0.01'); //
const abiCoder = new ethers.utils.AbiCoder();
const AUTH_TYPES = ['address', 'address', 'uint256', 'address'];

async function withdraw(
  participant,
  destination: Address,
  signer = participant,
  amount: ethers.utils.BigNumberish = DEPOSIT_AMOUNT,
  senderAddr = null,
  token = AddressZero,
): Promise<any> {
  senderAddr = senderAddr || (await nitroAdjudicator.signer.getAddress());
  const authorization = abiCoder.encode(AUTH_TYPES, [
    participant.address,
    destination,
    amount,
    senderAddr,
  ]);

  const sig = sign(authorization, signer.privateKey);
  return nitroAdjudicator.withdraw(
    participant.address,
    destination,
    amount,
    token,
    sig.v,
    sig.r,
    sig.s,
    {
      gasLimit: 3000000,
    },
  );
}

const provider = new ethers.providers.JsonRpcProvider(
  `http://localhost:${process.env.DEV_GANACHE_PORT}`,
);
const signer1 = provider.getSigner(1);

const alice = new ethers.Wallet(
  '0x5d862464fe9303452126c8bc94274b8c5f9874cbd219789b3eb2128075a76f72',
);
const bob = new ethers.Wallet('0xdf02719c4df8b9b8ac7f551fcb5d9ef48fa27eef7a66453879f4d8fdc6e78fb1');
const guarantor = ethers.Wallet.createRandom();
const aliceDest = ethers.Wallet.createRandom();
const aBal = ethers.utils.parseUnits('6', 'wei').toHexString();
const bBal = ethers.utils.parseUnits('4', 'wei').toHexString();
const allocation = [aBal, bBal];
const differentAllocation = [bBal, aBal];
const participants = [alice.address, bob.address];
const destination = [alice.address, bob.address];

const ledgerChannel: Channel = {
  channelType: '0x57153E563526c1ce131E6af71ffFDA2C3A50b980',
  nonce: 0,
  participants,
};
const guarantorChannel = {
  ...ledgerChannel,
  guaranteedChannel: getChannelID(ledgerChannel),
};
const getEthersObjectForCommitment = (commitment: CountingCommitment) => {
  return asEthersObject(countingCommitmentAsCoreCommitment(commitment));
};
const getOutcomeFromParameters = (parameters: any[]) => {
  const outcome = {
    destination: parameters[0],
    finalizedAt: ethers.utils.bigNumberify(parameters[1]),
    challengeCommitment: asEthersObject(fromParameters(parameters[2])),
    allocation: parameters[3].map(a => a.toHexString()),
    token: parameters[4],
  };
  return outcome;
};

const defaults = {
  channel: ledgerChannel,
  appCounter: new BigNumber(0).toHexString(),
  destination,
  allocation,
  token: [AddressZero, AddressZero],
  commitmentCount: 1,
};

const guarantorDefaults = {
  ...defaults,
  channel: guarantorChannel,
};

const commitment0 = CountingApp.createCommitment.app({
  ...defaults,
  appCounter: new BigNumber(1).toHexString(),
  turnNum: 6,
});

const guarantorCommitment = CountingApp.createCommitment.app({
  ...guarantorDefaults,
  appCounter: new BigNumber(1).toHexString(),
  turnNum: 6,
});

describe('Nitro (ETH management)', () => {
  let networkId;

  // ETH management
  // ========================

  beforeAll(async () => {
    networkId = (await provider.getNetwork()).chainId;
    const NitroAdjudicatorAddress = NitroAdjudicatorArtifact.networks[networkId].address;
    nitroAdjudicator = new ethers.Contract(
      NitroAdjudicatorAddress,
      NitroAdjudicatorArtifact.abi,
      signer1,
    );
    const nitroLibraryAddress = NitroLibraryArtifact.networks[networkId].address;
    nitroLibrary = new ethers.Contract(nitroLibraryAddress, NitroLibraryArtifact.abi, signer1);
  });

  describe('Depositing ETH (msg.value = amount , expectedHeld = 0)', () => {
    let receipt;
    const randomAddress = ethers.Wallet.createRandom().address;

    it('Transaction succeeds', async () => {
      receipt = await (await nitroAdjudicator.deposit(
        randomAddress,
        0,
        DEPOSIT_AMOUNT,
        AddressZero,
        {
          value: DEPOSIT_AMOUNT,
        },
      )).wait();
      await expect(receipt.status).toEqual(1);
    });

    it('Updates holdings', async () => {
      const allocatedAmount = await nitroAdjudicator.holdings(randomAddress, AddressZero);
      await expect(allocatedAmount).toEqual(DEPOSIT_AMOUNT);
    });

    it('Fires a deposited event', async () => {
      await expectEvent(receipt, 'Deposited', {
        destination: randomAddress,
        amountDeposited: bigNumberify(DEPOSIT_AMOUNT),
      });
    });
  });

  describe('Depositing ETH (msg.value = amount, expectedHeld > holdings)', () => {
    const randomAddress = ethers.Wallet.createRandom().address;

    it('Reverts', async () => {
      const tx = nitroAdjudicator.deposit(randomAddress, 10, DEPOSIT_AMOUNT, AddressZero, {
        value: DEPOSIT_AMOUNT,
      });
      await expectRevert(() => tx, 'Deposit: holdings[destination][token] is less than expected');
    });
  });

  describe('Depositing ETH (msg.value = amount, expectedHeld + amount < holdings)', () => {
    let tx;
    let receipt;
    let balanceBefore: BigNumber;
    const randomAddress = ethers.Wallet.createRandom().address;

    beforeAll(async () => {
      await (await nitroAdjudicator.deposit(randomAddress, 0, DEPOSIT_AMOUNT.mul(2), AddressZero, {
        value: DEPOSIT_AMOUNT.mul(2),
      })).wait();
      balanceBefore = await signer1.getBalance();
      tx = await nitroAdjudicator.deposit(randomAddress, 0, DEPOSIT_AMOUNT, AddressZero, {
        value: DEPOSIT_AMOUNT,
      });
      receipt = await tx.wait();
    });
    it('Emits Deposit of 0 event ', async () => {
      await expectEvent(receipt, 'Deposited', {
        destination: randomAddress,
        amountDeposited: bigNumberify(0),
      });
    });
    it('Refunds entire deposit', async () => {
      const gasCost = await tx.gasPrice.mul(receipt.cumulativeGasUsed);
      const balanceAfter = await signer1.getBalance();
      await expect(balanceAfter.eq(balanceBefore.sub(gasCost))).toBe(true);
    });
  });

  describe('Depositing ETH (msg.value = amount,  amount < holdings < amount + expectedHeld)', () => {
    let receipt;
    let balanceBefore;
    const randomAddress = ethers.Wallet.createRandom().address;

    beforeAll(async () => {
      await (await nitroAdjudicator.deposit(randomAddress, 0, DEPOSIT_AMOUNT.mul(11), AddressZero, {
        value: DEPOSIT_AMOUNT.mul(11),
      })).wait();
      balanceBefore = await signer1.getBalance();
      receipt = await (await nitroAdjudicator.deposit(
        randomAddress,
        DEPOSIT_AMOUNT.mul(10),
        DEPOSIT_AMOUNT.mul(2),
        AddressZero,
        {
          value: DEPOSIT_AMOUNT.mul(2),
        },
      )).wait();
    });
    it('Emits Deposit event (partial) ', async () => {
      await expectEvent(receipt, 'Deposited', {
        destination: randomAddress,
        amountDeposited: DEPOSIT_AMOUNT.mul(1),
      });
    });
    it('Partial refund', async () => {
      await expect(Number(await signer1.getBalance())).toBeGreaterThan(
        Number(balanceBefore.sub(DEPOSIT_AMOUNT.mul(2))),
      ); // TODO compute precisely, taking actual gas fees into account
    });
  });

  describe('Withdrawing ETH (signer = participant, holdings[participant][0x] = 2 * amount)', () => {
    let beforeBalance;
    let allocatedAtStart;
    const WITHDRAWAL_AMOUNT = DEPOSIT_AMOUNT;

    beforeAll(async () => {
      await (await nitroAdjudicator.deposit(alice.address, 0, DEPOSIT_AMOUNT.mul(2), AddressZero, {
        value: DEPOSIT_AMOUNT.mul(2),
      })).wait();
      allocatedAtStart = await nitroAdjudicator.holdings(alice.address, AddressZero);
      beforeBalance = await provider.getBalance(aliceDest.address);
    });

    it('Transaction succeeds', async () => {
      const receipt = await (await withdraw(
        alice,
        aliceDest.address,
        alice,
        WITHDRAWAL_AMOUNT,
      )).wait();
      await expect(receipt.status).toEqual(1);
    });

    it('Destination balance increases', async () => {
      await expect(await provider.getBalance(aliceDest.address)).toEqual(
        beforeBalance.add(WITHDRAWAL_AMOUNT),
      );
    });

    it('holdings[participant][0x] decreases', async () => {
      await expect(await nitroAdjudicator.holdings(alice.address, AddressZero)).toEqual(
        allocatedAtStart.sub(WITHDRAWAL_AMOUNT),
      );
    });
  });

  describe('Withdrawing ETH (signer =/= partcipant, holdings[participant][0x] = amount)', () => {
    let tx2;
    const WITHDRAWAL_AMOUNT = DEPOSIT_AMOUNT;

    beforeAll(async () => {
      await (await nitroAdjudicator.deposit(alice.address, 0, DEPOSIT_AMOUNT.mul(2), AddressZero, {
        value: DEPOSIT_AMOUNT.mul(2),
      })).wait();
      tx2 = withdraw(alice, aliceDest.address, bob, WITHDRAWAL_AMOUNT);
    });

    it('Reverts', async () => {
      await expectRevert(() => tx2, 'Withdraw: not authorized by participant');
    });
  });

  describe('Withdrawing ETH (signer = partcipant, holdings[participant][0x] < amount)', () => {
    let tx2;
    const WITHDRAWAL_AMOUNT = DEPOSIT_AMOUNT;

    beforeAll(async () => {
      tx2 = withdraw(bob, aliceDest.address, bob, WITHDRAWAL_AMOUNT);
    });

    it('Reverts', async () => {
      await expectRevert(() => tx2, 'Withdraw: overdrawn');
    });
  });

  describe('Withdrawing ETH (signer = partcipant, holdings[participant][0x] > amount)', () => {
    let tx2;
    const WITHDRAWAL_AMOUNT = DEPOSIT_AMOUNT;

    beforeAll(async () => {
      tx2 = withdraw(bob, aliceDest.address, bob, WITHDRAWAL_AMOUNT);
    });

    it('Reverts', async () => {
      await expectRevert(() => tx2, 'Withdraw: overdrawn');
    });
  });

  describe('Transferring ETH (outcome = final, holdings[fromChannel] > outcomes[fromChannel].destination', () => {
    let allocatedToChannel;
    let allocatedToAlice;
    beforeAll(async () => {
      const amountHeldAgainstLedgerChannel = await nitroAdjudicator.holdings(
        getChannelID(ledgerChannel),
        AddressZero,
      );
      await nitroAdjudicator.deposit(
        getChannelID(ledgerChannel),
        amountHeldAgainstLedgerChannel,
        DEPOSIT_AMOUNT,
        AddressZero,
        {value: DEPOSIT_AMOUNT},
      );
      const allocationOutcome = {
        destination: [alice.address, bob.address],
        allocation,
        finalizedAt: ethers.utils.bigNumberify(1),
        challengeCommitment: getEthersObjectForCommitment(commitment0),
        token: [AddressZero, AddressZero],
      };
      await (await nitroAdjudicator.setOutcome(
        getChannelID(ledgerChannel),
        allocationOutcome,
      )).wait();

      allocatedToChannel = await nitroAdjudicator.holdings(
        getChannelID(ledgerChannel),
        AddressZero,
      );
      allocatedToAlice = await nitroAdjudicator.holdings(alice.address, AddressZero);
    });

    it('Nitro.transfer tx succeeds', async () => {
      const tx1 = await nitroAdjudicator.transfer(
        getChannelID(ledgerChannel),
        alice.address,
        allocation[0],
        AddressZero,
      );
      const receipt1 = await tx1.wait();
      await expect(receipt1.status).toEqual(1);
    });

    it('holdings[to][0x] increases', async () => {
      await expect(await nitroAdjudicator.holdings(alice.address, AddressZero)).toEqual(
        allocatedToAlice.add(allocation[0]),
      );
    });

    it('holdings[from][0x] decreases', async () => {
      await expect(
        await nitroAdjudicator.holdings(getChannelID(ledgerChannel), AddressZero),
      ).toEqual(allocatedToChannel.sub(allocation[0]));
    });
  });

  describe('Transfer and withdraw ETH (outcome = final, holdings[fromChannel] > outcomes[fromChannel].destination', () => {
    let allocatedToChannel;
    let amountHeldAgainstLedgerChannel;
    let startBal;

    beforeAll(async () => {
      startBal = await provider.getBalance(aliceDest.address);
      amountHeldAgainstLedgerChannel = await nitroAdjudicator.holdings(
        getChannelID(ledgerChannel),
        AddressZero,
      );
      await (await nitroAdjudicator.deposit(
        getChannelID(ledgerChannel),
        amountHeldAgainstLedgerChannel,
        DEPOSIT_AMOUNT,
        AddressZero,
        {value: DEPOSIT_AMOUNT},
      )).wait();

      const allocationOutcome = {
        destination: [alice.address, bob.address],
        allocation,
        finalizedAt: ethers.utils.bigNumberify(1),
        challengeCommitment: getEthersObjectForCommitment(commitment0),
        token: [AddressZero, AddressZero],
      };
      await (await nitroAdjudicator.setOutcome(
        getChannelID(ledgerChannel),
        allocationOutcome,
      )).wait();

      allocatedToChannel = await nitroAdjudicator.holdings(
        getChannelID(ledgerChannel),
        AddressZero,
      );
    });

    it('Nitro.transferAndWithdraw tx succeeds', async () => {
      const authorization = abiCoder.encode(AUTH_TYPES, [
        alice.address,
        aliceDest.address,
        aBal,
        await signer1.getAddress(),
      ]);
      const sig = sign(authorization, alice.privateKey);
      const tx1 = await nitroAdjudicator.transferAndWithdraw(
        getChannelID(ledgerChannel),
        alice.address,
        aliceDest.address,
        allocation[0],
        AddressZero,
        sig.v,
        sig.r,
        sig.s,
        {gasLimit: 3000000},
      );
      const receipt1 = await tx1.wait();
      await expect(receipt1.status).toEqual(1);
    });

    it('EOA account balance increases', async () => {
      const expectedBalance = startBal.add(allocation[0]);
      const currentBalance = await provider.getBalance(aliceDest.address);
      await expect(currentBalance.eq(expectedBalance)).toBe(true);
    });

    it('holdings[channel][0x] decreases', async () => {
      const currentChannelHolding = await nitroAdjudicator.holdings(
        getChannelID(ledgerChannel),
        AddressZero,
      );
      const expectedChannelHolding = allocatedToChannel.sub(allocation[0]);
      await expect(currentChannelHolding).toEqual(expectedChannelHolding);
    });
  });

  describe('Claiming ETH from a Guarantor', () => {
    const finalizedAt = ethers.utils.bigNumberify(1);
    const recipient = bob.address;
    const claimAmount = ethers.utils.parseUnits('1', 'wei').toHexString();
    let expectedOutcome;
    let startBal;
    let startBalRecipient;

    beforeAll(async () => {
      const guarantee = {
        destination: [bob.address, alice.address],
        allocation: [],
        finalizedAt,
        challengeCommitment: getEthersObjectForCommitment(guarantorCommitment),
        token: [AddressZero, AddressZero],
      };
      const allocationOutcome = {
        destination: [alice.address, bob.address],
        allocation,
        finalizedAt,
        challengeCommitment: getEthersObjectForCommitment(guarantorCommitment),
        token: [AddressZero, AddressZero],
      };
      await (await nitroAdjudicator.setOutcome(guarantor.address, guarantee)).wait();
      await (await nitroAdjudicator.setOutcome(
        getChannelID(ledgerChannel),
        allocationOutcome,
      )).wait();

      // Other tests may have deposited into guarantor.address, but we
      // ensure that the guarantor has at least claimAmount in holdings
      const amountHeldAgainstGuarantor = await nitroAdjudicator.holdings(
        guarantor.address,
        AddressZero,
      );
      await (await nitroAdjudicator.deposit(
        guarantor.address,
        amountHeldAgainstGuarantor,
        claimAmount,
        AddressZero,
        {
          value: claimAmount,
        },
      )).wait();

      startBal = await nitroAdjudicator.holdings(guarantor.address, AddressZero);
      startBalRecipient = await nitroAdjudicator.holdings(recipient, AddressZero);
      const bAllocation = bigNumberify(bBal)
        .sub(claimAmount)
        .toHexString();
      const allocationAfterClaim = [aBal, bAllocation];
      expectedOutcome = {
        destination: [alice.address, bob.address],
        allocation: allocationAfterClaim,
        finalizedAt: ethers.utils.bigNumberify(finalizedAt),
        challengeCommitment: getEthersObjectForCommitment(guarantorCommitment),
        token: [AddressZero, AddressZero],
      };
    });

    it('Nitro.claim tx succeeds', async () => {
      const tx1 = await nitroAdjudicator.claim(
        guarantor.address,
        recipient,
        claimAmount,
        AddressZero,
      );
      const receipt1 = await tx1.wait();
      await expect(receipt1.status).toEqual(1);
    });

    it('New outcome registered', async () => {
      const newOutcome = await nitroAdjudicator.getOutcome(getChannelID(ledgerChannel));
      expect(getOutcomeFromParameters(newOutcome)).toMatchObject(expectedOutcome);
    });

    it('holdings[guarantor][0x] decreases', async () => {
      expect(await nitroAdjudicator.holdings(guarantor.address, AddressZero)).toEqual(
        startBal.sub(claimAmount),
      );
    });

    it('holdings[recipient][0x] increases', async () => {
      expect(await nitroAdjudicator.holdings(recipient, AddressZero)).toEqual(
        startBalRecipient.add(claimAmount),
      );
    });
  });

  describe('Using `setOutcome` public method', () => {
    const allocationOutcome = {
      destination: [alice.address, bob.address],
      allocation,
      finalizedAt: ethers.utils.bigNumberify(0),
      challengeCommitment: getEthersObjectForCommitment(commitment0),
      token: [AddressZero, AddressZero],
    };

    it('tx succeeds', async () => {
      const tx = await nitroAdjudicator.setOutcome(getChannelID(ledgerChannel), allocationOutcome);
      const receipt = await tx.wait();
      await expect(receipt.status).toEqual(1);
    });
    it('sets outcome', async () => {
      const setOutcome = await nitroAdjudicator.getOutcome(getChannelID(ledgerChannel));
      await expect(getOutcomeFromParameters(setOutcome)).toMatchObject(allocationOutcome);
    });
  });
  describe('Using `affords` public method', () => {
    const outcome = {
      destination: [alice.address, bob.address],
      allocation,
      finalizedAt: ethers.utils.bigNumberify(0),
      challengeCommitment: getEthersObjectForCommitment(commitment0),
      token: [AddressZero, AddressZero],
    };
    it('returns funding when funding is less than the amount allocated to the recipient in the outcome', async () => {
      const recipient = alice.address;
      const funding = ethers.utils.bigNumberify(2);
      await expect(await nitroLibrary.affords(recipient, outcome, funding)).toEqual(funding);
    });

    it('returns funding when funding is equal to the amount allocated to the recipient in the outcome', async () => {
      const recipient = alice.address;
      const funding = aBal;
      await expect((await nitroLibrary.affords(recipient, outcome, funding)).toHexString()).toEqual(
        funding,
      );
    });

    it('returns the allocated amount when funding is greater than the amount allocated to the recipient in the outcome', async () => {
      const recipient = alice.address;
      const funding = bigNumberify(aBal)
        .add(1)
        .toHexString();
      await expect((await nitroLibrary.affords(recipient, outcome, funding)).toHexString()).toEqual(
        aBal,
      );
    });

    it('returns zero when recipient is not a participant', async () => {
      const recipient = aliceDest.address;
      const funding = bigNumberify(aBal)
        .add(1)
        .toHexString();
      const zero = ethers.utils.bigNumberify(0);
      await expect(await nitroLibrary.affords(recipient, outcome, funding)).toEqual(zero);
    });
  });

  describe('Using `reduce` public method', () => {
    const outcome = {
      destination: [alice.address, bob.address],
      allocation,
      finalizedAt: ethers.utils.bigNumberify(0),
      challengeCommitment: getEthersObjectForCommitment(commitment0),
      token: [AddressZero, AddressZero],
    };
    const reduceAmount = 2;
    const expectedBAllocation = bigNumberify(bBal)
      .sub(reduceAmount)
      .toHexString();
    const allocationAfterReduce = [aBal, expectedBAllocation];

    const expectedOutcome = {
      destination: [alice.address, bob.address],
      allocation: allocationAfterReduce,
      finalizedAt: ethers.utils.bigNumberify(0),
      challengeCommitment: getEthersObjectForCommitment(commitment0),
      token: [AddressZero, AddressZero],
    };

    const recipient = bob.address;
    it('Allocation reduced correctly', async () => {
      const newOutcome = await nitroLibrary.reduce(outcome, recipient, reduceAmount, AddressZero);

      expect(getOutcomeFromParameters(newOutcome)).toMatchObject(expectedOutcome);
    });
  });

  describe('Using `reprioritize` public method', () => {
    it("works when the guarantee destination length matches the allocation outcome's allocation length", async () => {
      const allocationOutcome = {
        destination: [alice.address, bob.address],
        allocation,
        finalizedAt: ethers.utils.bigNumberify(0),
        challengeCommitment: getEthersObjectForCommitment(commitment0),
        token: [AddressZero, AddressZero],
      };

      const guarantee = {
        destination: [bob.address, alice.address],
        allocation: [],
        finalizedAt: ethers.utils.bigNumberify(0),
        challengeCommitment: getEthersObjectForCommitment(guarantorCommitment),
        guaranteedChannel: getChannelID(ledgerChannel),
        token: [AddressZero, AddressZero],
      };

      const expectedOutcome = {
        destination: [bob.address, alice.address],
        allocation: differentAllocation,
        finalizedAt: ethers.utils.bigNumberify(0),
        challengeCommitment: getEthersObjectForCommitment(commitment0),
        token: [AddressZero, AddressZero],
      };

      const newOutcome = await nitroLibrary.reprioritize(allocationOutcome, guarantee);
      expect(getOutcomeFromParameters(newOutcome)).toMatchObject(expectedOutcome);
    });

    it("works when the guarantee destination length is less than the allocation outcome's allocation length", async () => {
      const allocationOutcome = {
        destination: [alice.address, bob.address],
        allocation,
        finalizedAt: ethers.utils.bigNumberify(0),
        challengeCommitment: getEthersObjectForCommitment(commitment0),
        token: [AddressZero, AddressZero],
      };

      const guarantee = {
        destination: [bob.address],
        allocation: [],
        finalizedAt: ethers.utils.bigNumberify(0),
        challengeCommitment: getEthersObjectForCommitment(guarantorCommitment),
        guaranteedChannel: getChannelID(ledgerChannel),
        token: [AddressZero, AddressZero],
      };

      const expectedOutcome = {
        destination: [bob.address],
        allocation: [bBal],
        finalizedAt: ethers.utils.bigNumberify(0),
        challengeCommitment: getEthersObjectForCommitment(commitment0),
        token: [AddressZero, AddressZero],
      };

      const newOutcome = await nitroLibrary.reprioritize(allocationOutcome, guarantee);

      expect(getOutcomeFromParameters(newOutcome)).toMatchObject(expectedOutcome);
    });
  });
});
