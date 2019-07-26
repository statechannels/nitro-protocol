pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Outcome.sol";
import "./NitroLibrary.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract AssetHolder {
    using SafeMath for uint256;
    // TODO: Challenge duration should depend on the channel
    uint256 constant CHALLENGE_DURATION = 5 minutes;
    address private constant zeroAddress = address(0);

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

    mapping(address => uint256) public holdings;

    mapping(address => Outcome.SingleAssetOutcomeWithMetaData) public outcomes;

    // **************
    // ETH and Token Management
    // **************
    function transfer(address channel, address destination, uint256 amount) public {
        require(
            outcomes[channel].singleAssetOutcome.guaranteedChannel == zeroAddress,
            "Transfer: channel must not be a guarantor channel"
        );
        require(outcomes[channel].finalizedAt <= now, "Transfer: outcome must be final");
        require(outcomes[channel].finalizedAt > 0, "Transfer: outcome must be present");

        uint256 channelAffordsForDestination = affords(
            destination,
            outcomes[channel].singleAssetOutcome.allocations,
            holdings[channel]
        );

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

    function claim(address guarantor, address recipient, uint256 amount) public {
        Outcome.SingleAssetOutcome memory guarantee = outcomes[guarantor].singleAssetOutcome;
        require(
            // guarantee.challengeCommitment.guaranteedChannel != zeroAddress,
            guarantee.guaranteedChannel != zeroAddress,
            "Claim: a guarantee channel is required"
        );

        require(isChannelClosed(guarantor), "Claim: channel must be closed");

        uint256 funding = holdings[guarantor];
        Outcome.allocation[] memory reprioritizedAllocations = reprioritize(
            outcomes[guarantee.guaranteedChannel].singleAssetOutcome.allocations,
            guarantee.allocations
        );
        if (affords(recipient, reprioritizedAllocations, funding) >= amount) {
            outcomes[guarantee.guaranteedChannel].singleAssetOutcome.allocations = reduce(
                outcomes[guarantee.guaranteedChannel].singleAssetOutcome.allocations,
                recipient,
                amount
            );
            holdings[guarantor] = holdings[guarantor].sub(amount);
            holdings[recipient] = holdings[recipient].add(amount);
        } else {
            revert("Claim: guarantor must be sufficiently funded");
        }
    }

    function reprioritize(
        Outcome.allocation[] memory allocation,
        Outcome.allocation[] memory guarantee
    ) public pure returns (Outcome.allocation[] memory) {
        Outcome.allocation[] memory newAllocations = new Outcome.allocation[](guarantee.length);
        for (uint256 aIdx = 0; aIdx < allocation.length; aIdx++) {
            for (uint256 gIdx = 0; gIdx < guarantee.length; gIdx++) {
                if (guarantee[gIdx].participant == allocation[aIdx].participant) {
                    newAllocations[gIdx] = allocation[aIdx];
                    break;
                }
            }
        }
        return newAllocations;
    }

     function affords(address recipient, Outcome.allocation[] memory allocations, uint256 funding)
        public
        pure
        returns (uint256)
    {
        uint256 result = 0;
        uint256 remainingFunding = funding;

        for (uint256 i = 0; i < allocations.length; i++) {
            if (remainingFunding <= 0) {
                break;
            }

            if (allocations[i].participant == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                result = result.add(min(allocations[i].amount, remainingFunding));
            }
            if (remainingFunding > allocations[i].amount) {
                remainingFunding = remainingFunding.sub(allocations[i].amount);
            } else {
                remainingFunding = 0;
            }
        }

        return result;
    }


    function reduce(
        Outcome.allocation[] memory allocations,
        address recipient,
        uint256 amount
    ) public pure returns (Outcome.allocation[] memory) {
        // TODO only reduce entries corresponding to token argument
        Outcome.allocation[] memory updatedAllocations = allocations;
        uint256 reduction = 0;
        uint256 remainingAmount = amount;
        for (uint256 i = 0; i < allocations.length; i++) {
            if (allocations[i].participant == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                reduction = reduction.add(min(allocations[i].amount, remainingAmount));
                remainingAmount = remainingAmount.sub(reduction);
                updatedAllocations[i].amount = updatedAllocations[i].amount.sub(reduction);
            }
        }

        return updatedAllocations;
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        if (a <= b) {
            return a;
        }

        return b;
    }

    function isChannelClosed(address channel) internal view returns (bool) {
        return outcomes[channel].finalizedAt < now && outcomes[channel].finalizedAt > 0;
    }

    // ****************
    // Events
    // ****************
    event Deposited(address destination, uint256 amountDeposited, uint256 destinationHoldings);

}
