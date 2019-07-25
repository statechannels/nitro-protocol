pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Outcome.sol";
import "./NitroLibrary.sol";
import "./AssetHolder.sol";
contract ETHAssetHolder is AssetHolder {
    constructor(address _AdjudicatorAddress) public {
        address AdjudicatorAddress = _AdjudicatorAddress;
    }

    modifier AdjudicatorOnly {
        require(msg.sender == AdjudicatorAddress, "Only the NitroAdjudicator is authorized");
        _;
    }

    // TODO: Challenge duration should depend on the channel
    uint256 constant CHALLENGE_DURATION = 5 minutes;

    struct Authorization {
        // Prevents replay attacks:
        // It's required that the participant signs the message, meaning only
        // the participant can authorize a withdrawal.
        // Moreover, the participant should sign the address that they wish
        // to send the transaction from, preventing any replay attack.
        address participant; // the account used to sign commitment transitions
        address destination; // either an account or a channel
        uint256 amount;
        address sender; // the account used to sign transactions
    }

    struct ConclusionProof {
        Commitment.CommitmentStruct penultimateCommitment;
        INitroLibrary.Signature penultimateSignature;
        Commitment.CommitmentStruct ultimateCommitment;
        INitroLibrary.Signature ultimateSignature;
    }

    mapping(address => uint256) public holdings;

    // the outcomes in the Nitro network are spread over several AssetHolder contracts
    // If they were in a single contract, we could store this information as:
    // mapping(address => SingleAssetOutcome[]] ) outcomes;
    // e.g. {
    //     0xChannel1 => [
    //      {
    //         0xAssetHolder1,
    //         [{0xAlice, 5}, {0XBob, 3}]
    //     },
    //     {
    //         0xAssetHolder2,
    //         [{0xAlice, 1}, {0XBob, 6}]
    //      }]
    // }
    //
    // Since we are only concerned with a slice of this object here, we use
    mapping(address => Outcome.allocation[]) public outcomes;
    // TODO incorporate finalizesAt time

    // **************
    // Permissioned methods
    // **************

    function setOutcome(address channel, Outcome.allocation[] memory outcome)
        internal
        AdjudicatorOnly
    {
        outcomes[channel] = outcome;
    }

    function setOutcome(address channel) internal AdjudicatorOnly {
        outcomes[channel] = 0;
    }

    // **************
    // ETH and Token Management
    // **************

    function deposit(address destination, uint256 expectedHeld, uint256 amount) public payable {
        require(msg.value == amount, "Insufficient ETH for ETH deposit");
        uint256 amountDeposited;
        // This protects against a directly funded channel being defunded due to chain re-orgs,
        // and allow a wallet implementation to ensure the safety of deposits.
        require(
            holdings[destination] >= expectedHeld,
            "Deposit: holdings[destination] is less than expected"
        );

        // If I expect there to be 10 and deposit 2, my goal was to get the
        // balance to 12.
        // In case some arbitrary person deposited 1 eth before I noticed, making the
        // holdings 11, I should be refunded 1.
        if (holdings[destination] == expectedHeld) {
            amountDeposited = amount;
        } else if (holdings[destination] < expectedHeld.add(amount)) {
            amountDeposited = expectedHeld.add(amount).sub(holdings[destination]);
        } else {
            amountDeposited = 0;
        }
        holdings[destination] = holdings[destination].add(amountDeposited);
        if (amountDeposited < amount) {
            // refund whatever wasn't deposited.
            msg.sender.transfer(amount - amountDeposited); // TODO use safeMath here
        }
        emit Deposited(destination, amountDeposited, holdings[destination]);
    }

    function withdraw(
        address participant,
        address payable destination,
        uint256 amount,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable {
        require(holdings[participant] >= amount, "Withdraw: overdrawn");
        Authorization memory authorization = Authorization(
            participant,
            destination,
            amount,
            msg.sender
        );

        require(
            Library.recoverSigner(abi.encode(authorization), _v, _r, _s) == participant,
            "Withdraw: not authorized by participant"
        );

        holdings[participant] = holdings[participant].sub(amount);
        // Decrease holdings before calling to token contract (protect against reentrancy)
        destination.transfer(amount);
    }
}
