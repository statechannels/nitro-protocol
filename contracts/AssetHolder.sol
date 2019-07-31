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
    address AdjudicatorAddress;

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

    mapping(address => bytes) public outcomes;

    mapping(address => uint256) public finalizationTimes;

    // **************
    // Permissioned methods
    // **************

    modifier AdjudicatorOnly {
        require(msg.sender == AdjudicatorAddress, "Only the NitroAdjudicator is authorized");
        _;
    }

    function _setOutcome(
        address channel,
        bytes memory outcome,
        uint256 finalizedAt
    ) internal {
        outcomes[channel] = outcome;
        finalizationTimes[channel] = finalizedAt;
    }

    function setOutcome(
        address channel,
        bytes memory outcome,
        uint256 finalizedAt
    )
        public
        AdjudicatorOnly
    {
        require(isChannelFinalized(channel),            "Conclude: channel must not be finalized"
        );
        _setOutcome(channel, outcome, finalizedAt);
    }

    function _clearOutcome(address channel) internal {
        delete outcomes[channel];
        delete finalizationTimes[channel];
    }

    function clearOutcome(address channel) public AdjudicatorOnly {
        require(!isChannelFinalized(channel),
            "Conclude: channel must not be finalized"
        );
        _clearOutcome(channel);
    }

    // **************
    // ETH and Token Management
    // **************
    function transfer(address channel, address destination, uint256 amount) public {
        Outcome.AssetOutcome memory assetOutcome = Outcome.getAssetOutcome(outcomes[channel]);
        require(
            Outcome.isAllocation(assetOutcome),
            "Transfer: channel must not be a guarantor channel"
        );
        require(!isChannelFinalized(channel),
            "Transfer: channel must be finalized"
        );

        Outcome.AllocationItem[] memory allocation = Outcome.getAllocation(assetOutcome.outcomeContent);
        uint256 channelAffordsForDestination = affords(
            destination,
            allocation,
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
        Outcome.Guarantee memory guarantee = Outcome.getGuarantee(Outcome.getAssetOutcome(outcomes[guarantor]).outcomeContent);
        require(
            // guarantee.challengeCommitment.guaranteedChannel != zeroAddress,
            guarantee.guaranteedChannelId != zeroAddress,
            "Claim: a guarantee channel is required"
        );

        require(isChannelFinalized(guarantor), "Claim: channel must be closed");

        uint256 funding = holdings[guarantor];
        Outcome.AllocationItem[] memory originalAllocation = Outcome.getAllocation(Outcome.getAssetOutcome(outcomes[guarantee.guaranteedChannelId]).outcomeContent);
        Outcome.AllocationItem[] memory reprioritizedAllocation = reprioritize(
            originalAllocation,
            guarantee
        );
        if (affords(recipient, reprioritizedAllocation, funding) >= amount) {
            Outcome.AllocationItem[] memory reducedAllocations = reduce(
                originalAllocation,
                recipient,
                amount
            );
            outcomes[guarantee.guaranteedChannelId] = Outcome.encode(reducedAllocations); // TODO write the encode function
            holdings[guarantor] = holdings[guarantor].sub(amount);
            holdings[recipient] = holdings[recipient].add(amount);
        } else {
            revert("Claim: guarantor must be sufficiently funded");
        }
    }

    function reprioritize(
        Outcome.AllocationItem[] memory allocation,
        Outcome.Guarantee memory guarantee
    ) public pure returns (Outcome.AllocationItem[] memory) {

        Outcome.AllocationItem[] memory newAllocation = new Outcome.AllocationItem[](guarantee.length);
        for (uint256 aIdx = 0; aIdx < allocation.length; aIdx++) {
            for (uint256 gIdx = 0; gIdx < guarantee.length; gIdx++) {
                if (guarantee.destinations[gIdx] == allocation[aIdx].destination) {
                    newAllocation[gIdx] = allocation[aIdx];
                    break;
                }
            }
        }
        return newAllocation;
    }

     function affords(address recipient, Outcome.AllocationItem[] memory allocation, uint256 funding)
        public
        pure
        returns (uint256)
    {
        uint256 result = 0;
        uint256 remainingFunding = funding;

        for (uint256 i = 0; i < allocation.length; i++) {
            if (remainingFunding <= 0) {
                break;
            }

            if (allocation[i].destination == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                result = result.add(min(allocation[i].amount, remainingFunding));
            }
            if (remainingFunding > allocation[i].amount) {
                remainingFunding = remainingFunding.sub(allocation[i].amount);
            } else {
                remainingFunding = 0;
            }
        }

        return result;
    }


    function reduce(
        Outcome.AllocationItem[] memory allocation,
        address recipient,
        uint256 amount
    ) public pure returns (Outcome.AllocationItem[] memory) {
        Outcome.AllocationItem[] memory updatedAllocation = allocation;
        uint256 reduction = 0;
        uint256 remainingAmount = amount;
        for (uint256 i = 0; i < allocation.length; i++) {
            if (allocation[i].destination == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                reduction = reduction.add(min(allocation[i].amount, remainingAmount));
                remainingAmount = remainingAmount.sub(reduction);
                updatedAllocation[i].amount = updatedAllocation[i].amount.sub(reduction);
            }
        }

        return updatedAllocation;
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        if (a <= b) {
            return a;
        }

        return b;
    }

    function isChannelFinalized(address channel) internal view returns (bool) {
        return finalizationTimes[channel] < now && finalizationTimes[channel] > 0;
    }

        function recoverSigner(bytes memory _d, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (address)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, h));

        address a = ecrecover(prefixedHash, _v, _r, _s);

        return (a);
    }

    // ****************
    // Events
    // ****************
    event Deposited(address destination, uint256 amountDeposited, uint256 destinationHoldings);

}
