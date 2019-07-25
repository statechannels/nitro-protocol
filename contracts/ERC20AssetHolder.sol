pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Outcome.sol";
import "./NitroLibrary.sol";
import "./AssetHolder.sol";

contract ERC20AssetHolder is AssetHolder {

    constructor(address _AdjudicatorAddress, address _TokenAddress) public {
        address AdjudicatorAddress = _AdjudicatorAddress;
        address TokenAddress = _TokenAddress;
    }

    modifier AdjudicatorOnly {
        require(msg.sender == AdjudicatorAddress)
        _;
    }

    IERC20 _token = IERC20(TokenAddress);

    // **************
    // Asset Management
    // **************


function deposit(address destination, uint expectedHeld,
 uint amount) public {
        require(_token.transferFrom(msg.sender,address(this),amount), 'Could not deposit ERC20s');

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
                _token.transfer(msg.sender, amount - amountDeposited); // TODO use safeMath here
                // TODO compute amountDeposited *before* calling into erc20 contract, so we only need 1 call not 2
        }
        emit Deposited(destination, amountDeposited, holdings[destination]);
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
        // Decrease holdings before calling transfer (protect against reentrancy)
        _token.transfer(destination,amount);
    }

}