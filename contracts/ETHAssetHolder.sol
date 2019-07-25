pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Outcome.sol";
contract AssetHolder {

    constructor(address _AdjudicatorAddress) public {
        address AdjudicatorAddress = _AdjudicatorAddress;
    }

    modifier AdjudicatorOnly {
        require(msg.sender == AdjudicatorAddress)
        _;
    }

    // TODO: Challenge duration should depend on the channel
    uint constant CHALLENGE_DURATION = 5 minutes;

    struct Authorization {
        // Prevents replay attacks:
        // It's required that the participant signs the message, meaning only
        // the participant can authorize a withdrawal.
        // Moreover, the participant should sign the address that they wish
        // to send the transaction from, preventing any replay attack.
        address participant; // the account used to sign commitment transitions
        address destination; // either an account or a channel
        uint amount;
        address sender; // the account used to sign transactions
    }

    struct ConclusionProof {
        Commitment.CommitmentStruct penultimateCommitment;
        INitroLibrary.Signature penultimateSignature; // Abs
        Commitment.CommitmentStruct ultimateCommitment;
        INitroLibrary.Signature ultimateSignature; // Abs
    }

    mapping(address => uint) public holdings;
    
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

     function setOutcome(address channel, Outcome.allocation[] memory outcome) AdjudicatorOnly {
        outcomes[channel] = outcome;
    }

    function setOutcome(address channel) AdjudicatorOnly {
        outcomes[channel] = {};
    }

    // **************
    // ETH and Token Management
    // **************


function deposit(address destination, uint expectedHeld,
 uint amount) public payable {
        require(msg.value == amount, "Insufficient ETH for ETH deposit");
        uint amountDeposited;
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

    function transferAndWithdraw(address channel,
        address participant,
        address payable destination,
        uint amount,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable {
        transfer(channel, participant, amount);
        withdraw(participant, destination, amount, _v, _r ,_s);
    }

    function withdraw(address participant,
        address payable destination,
        uint amount,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable {
        require(
            holdings[participant] >= amount,
            "Withdraw: overdrawn"
        );
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


    function transfer(address channel, address destination, uint amount) public {
        require(
            outcomes[channel].challengeCommitment.guaranteedChannel == zeroAddress,
            "Transfer: channel must be a ledger channel"
        );
        require(
            outcomes[channel].finalizedAt <= now,
            "Transfer: outcome must be final"
        );
        require(
            outcomes[channel].finalizedAt > 0,
            "Transfer: outcome must be present"
        );

        uint channelAffordsForDestination = Library.affords(destination, outcomes[channel], holdings[channel]);

        require(
            amount <= channelAffordsForDestination,
            "Transfer: channel cannot afford the requested transfer amount"
        );

        holdings[destination] = holdings[destination] + amount;
        holdings[channel] = holdings[channel] - amount;
    }

    // TODO this is a mix of asset management and outcome management
    // TODO figure out if / how we still support this
    // function concludeAndWithdraw(ConclusionProof memory proof,
    //     address participant,
    //     address payable destination,
    //     uint amount,
    //     address token,
    //     uint8 _v,
    //     bytes32 _r,
    //     bytes32 _s
    // ) public{
    //     address channelId = proof.penultimateCommitment.channelId();
    //     if (outcomes[channelId].finalizedAt > now || outcomes[channelId].finalizedAt == 0){
    //     _conclude(proof);
    //     } else {
    //         require(keccak256(abi.encode(proof.penultimateCommitment)) == keccak256(abi.encode(outcomes[channelId].challengeCommitment)),
    //         "concludeAndWithdraw: channel already concluded with a different proof");
    //     }
    //     transfer(channelId,participant, amount, token);
    //     withdraw(participant,destination, amount, token, _v,_r,_s);
    // }

    function claim(address guarantor, address recipient, uint amount) public {
        INitroLibrary.Outcome memory guarantee = outcomes[guarantor]; // Abs
        require(
            guarantee.challengeCommitment.guaranteedChannel != zeroAddress,
            "Claim: a guarantee channel is required"
        );

        require(
            isChannelClosed(guarantor),
            "Claim: channel must be closed"
        );

        uint funding = holdings[guarantor];
        INitroLibrary.Outcome memory reprioritizedOutcome = Library.reprioritize( // Abs
            outcomes[guarantee.challengeCommitment.guaranteedChannel],
            guarantee
        );
        if (Library.affords(recipient, reprioritizedOutcome, funding) >= amount) {
            outcomes[guarantee.challengeCommitment.guaranteedChannel] = Library.reduce(
                outcomes[guarantee.challengeCommitment.guaranteedChannel],
                recipient,
                amount,
                token
            );
            holdings[guarantor] = holdings[guarantor].sub(amount);
            holdings[recipient] = holdings[recipient].add(amount);
        } else {
            revert('Claim: guarantor must be sufficiently funded');
        }
    }

    // ****************
    // Events
    // ****************
    event Deposited(address destination, uint256 amountDeposited, uint256 destinationHoldings);

}