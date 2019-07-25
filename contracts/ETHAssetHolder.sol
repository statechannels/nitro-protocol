pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Outcome.sol";
import "./NitroLibrary.sol";
import "./AssetHolder.sol";
contract ETHAssetHolder is AssetHolder {
    address AdjudicatorAddress;

    constructor(address _AdjudicatorAddress) public {
        AdjudicatorAddress = _AdjudicatorAddress;
    }

    modifier AdjudicatorOnly {
        require(msg.sender == AdjudicatorAddress, "Only the NitroAdjudicator is authorized");
        _;
    }

    // TODO: Challenge duration should depend on the channel
    uint256 constant CHALLENGE_DURATION = 5 minutes;

    // **************
    // Permissioned methods
    // **************

    function _setOutcome(
        address channel,
        Outcome.SingleAssetOutcome memory outcome,
        uint256 finalizedAt,
        Commitment.CommitmentStruct challengeCommitment
    ) internal {
        outcomes[channel] = outcome;
    }

    function setOutcome(address channel, Outcome.SingleAssetOutcome memory outcome)
        public
        AdjudicatorOnly
    {
        require(
            (outcomes[channel].finalizedAt > now || outcomes[channel].finalizedAt == 0),
            "Conclude: channel must not be finalized"
        );
        _setOutcome(channel, outcome);
    }

    function _clearOutcome(address channel) internal {
        outcomes[channel] = 0;
    }

    function clearOutcome(address channel) public AdjudicatorOnly {
        require(
            (outcomes[channel].finalizedAt > now || outcomes[channel].finalizedAt == 0),
            "Conclude: channel must not be finalized"
        );
        _clearOutcome(channel);
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
            NitroLibrary.recoverSigner(abi.encode(authorization), _v, _r, _s) == participant,
            "Withdraw: not authorized by participant"
        );

        holdings[participant] = holdings[participant].sub(amount);
        // Decrease holdings before calling to token contract (protect against reentrancy)
        destination.transfer(amount);
    }

    function transferAndWithdraw(
        address channel,
        address participant,
        address payable destination,
        uint256 amount,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable {
        transfer(channel, participant, amount);
        withdraw(participant, destination, amount, _v, _r, _s);
    }
}
