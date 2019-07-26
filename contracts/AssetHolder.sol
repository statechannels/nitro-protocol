pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "./Outcome.sol";
import "./NitroLibrary.sol";
contract AssetHolder {
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
            outcomes[channel],
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
        Outcome.SingleAssetOutcome memory guarantee = outcomes[guarantor];
        require(
            guarantee.challengeCommitment.guaranteedChannel != zeroAddress,
            "Claim: a guarantee channel is required"
        );

        require(isChannelClosed(guarantor), "Claim: channel must be closed");

        uint256 funding = holdings[guarantor];
        Outcome.SingleAssetOutcome memory reprioritizedOutcome = reprioritize(
            outcomes[guarantee.challengeCommitment.guaranteedChannel],
            guarantee
        );
        if (affords(recipient, reprioritizedOutcome, funding) >= amount) {
            outcomes[guarantee.challengeCommitment.guaranteedChannel] = NitroLibrary.reduce(
                outcomes[guarantee.challengeCommitment.guaranteedChannel],
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
        Outcome.SingleAssetOutcome memory allocation,
        Outcome.SingleAssetOutcome memory guarantee
    ) public pure returns (Outcome.SingleAssetOutcome memory) {
        Outcome.allocation[] memory newOutcome = new Outcome.allocation[](guarantee.allocations.length);
        for (uint256 aIdx = 0; aIdx < allocation.allocations.length; aIdx++) {
            for (uint256 gIdx = 0; gIdx < guarantee.allocations.length; gIdx++) {
                if (guarantee.allocation[gIdx].participant == allocation.allocation[aIdx].participant) {
                    newOutcome[gIdx] = allocation.allocation[aIdx];
                    break;
                }
            }
        }

        return newOutcome;
    }

     function affords(address recipient, Outcome.SingleAssetOutcome memory outcome, uint256 funding)
        public
        pure
        returns (uint256)
    {
        uint256 result = 0;
        uint256 remainingFunding = funding;

        for (uint256 i = 0; i < outcome.allocations.length; i++) {
            if (remainingFunding <= 0) {
                break;
            }

            if (outcome.allocations[i].participant == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                result = result.add(min(outcome.allocations[i].amount, remainingFunding));
            }
            if (remainingFunding > outcome.allocations[i].amount) {
                remainingFunding = remainingFunding.sub(outcome.allocations[i].amount);
            } else {
                remainingFunding = 0;
            }
        }

        return result;
    }


    function reduce(
        Outcome.SingleAssetOutcome memory outcome,
        address recipient,
        uint256 amount,
        address token
    ) public pure returns (Outcome.SingleAssetOutcome memory) {
        // TODO only reduce entries corresponding to token argument
        uint256[] memory updatedAllocation = outcome.allocation;
        uint256 reduction = 0;
        uint256 remainingAmount = amount;
        for (uint256 i = 0; i < outcome.destination.length; i++) {
            if (outcome.destination[i] == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                reduction = reduction.add(min(outcome.allocation[i], remainingAmount));
                remainingAmount = remainingAmount.sub(reduction);
                updatedAllocation[i] = updatedAllocation[i].sub(reduction);
            }
        }

        return
            Outcome(
                outcome.destination,
                outcome.finalizedAt,
                outcome.challengeCommitment, // Once the outcome is finalized,
                updatedAllocation,
                outcome.token
            );
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
