pragma solidity ^0.5.11;
pragma experimental ABIEncoderV2;
import './Outcome.sol';
import './AssetHolder.sol';
contract ETHAssetHolder is AssetHolder {
    address AdjudicatorAddress;

    constructor(address _AdjudicatorAddress) public {
        AdjudicatorAddress = _AdjudicatorAddress;
    }

    modifier AdjudicatorOnly {
        require(msg.sender == AdjudicatorAddress, 'Only the NitroAdjudicator is authorized');
        _;
    }

    function deposit(bytes32 destination, uint256 expectedHeld, uint256 amount) public payable {
        require(!_isExternalAddress(destination), 'Cannot deposit to external address');
        require(msg.value == amount, 'Insufficient ETH for ETH deposit');
        uint256 amountDeposited;
        // this allows participants to reduce the wait between deposits, while protecting them from losing funds by depositing too early. Specifically it protects against the scenario:
        // 1. Participant A deposits
        // 2. Participant B sees A's deposit, which means it is now safe for them to deposit
        // 3. Participant B submits their deposit
        // 4. The chain re-orgs, leaving B's deposit in the chain but not A's
        require(
            holdings[destination] >= expectedHeld,
            'Deposit | holdings[destination] is less than expected'
        );
        require(
            holdings[destination] < expectedHeld.add(amount),
            'Deposit | holdings[destination] already meets or exceeds expectedHeld + amount'
        );

        // The depositor wishes to increase the holdings against channelId to amount + expectedHeld
        // The depositor need only deposit (at most) amount + (expectedHeld - holdings) (the term in parentheses is non-positive)

        amountDeposited = expectedHeld.add(amount).sub(holdings[destination]); // strictly positive
        // require successful deposit before updating holdings (protect against reentrancy)
        // refund whatever wasn't deposited.
        msg.sender.transfer(amount.sub(amountDeposited));
        holdings[destination] = holdings[destination].add(amountDeposited);
        emit Deposited(destination, amountDeposited, holdings[destination]);
    }

    function _transferAsset(address payable destination, uint256 amount) internal {
        destination.transfer(amount);
    }

}
