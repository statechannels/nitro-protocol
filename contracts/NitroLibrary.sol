pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Commitment.sol";
import "./Outcome.sol";

contract NitroLibrary {
    using Commitment for Commitment.CommitmentStruct;
    using SafeMath for uint256;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // struct Outcome {
    //     address[] destination;
    //     uint256 finalizedAt;
    //     Commitment.CommitmentStruct challengeCommitment;
    //     // exactly one of the following two should be non-null
    //     // guarantee channels
    //     uint256[] allocation; // should be zero length in guarantee channels
    //     address[] token;
    // }

    address private constant zeroAddress = address(0);

    function reprioritize(
        Outcome.SingleAssetOutcome memory allocation,
        Outcome.SingleAssetOutcome memory guarantee
    ) public pure returns (Outcome.SingleAssetOutcome memory) {
        require(
            guarantee.challengeCommitment.guaranteedChannel != zeroAddress,
            "Claim: a guarantee channel is required"
        );
        address[] memory newDestination = new address[](guarantee.destination.length);
        uint256[] memory newAllocation = new uint256[](guarantee.destination.length);
        for (uint256 aIdx = 0; aIdx < allocation.destination.length; aIdx++) {
            for (uint256 gIdx = 0; gIdx < guarantee.destination.length; gIdx++) {
                if (guarantee.destination[gIdx] == allocation.destination[aIdx]) {
                    newDestination[gIdx] = allocation.destination[aIdx];
                    newAllocation[gIdx] = allocation.allocation[aIdx];
                    break;
                }
            }
        }

        return
            Outcome(
                newDestination,
                allocation.finalizedAt,
                allocation.challengeCommitment,
                newAllocation,
                allocation.token
            );
    }

    function affords(address recipient, Outcome.SingleAssetOutcome memory outcome, uint256 funding)
        public
        pure
        returns (uint256)
    {
        uint256 result = 0;
        uint256 remainingFunding = funding;

        for (uint256 i = 0; i < outcome.destination.length; i++) {
            if (remainingFunding <= 0) {
                break;
            }

            if (outcome.destination[i] == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                result = result.add(min(outcome.allocation[i], remainingFunding));
            }
            if (remainingFunding > outcome.allocation[i]) {
                remainingFunding = remainingFunding.sub(outcome.allocation[i]);
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
            Outcome.SingleAssetOutcome(
                outcome.destination,
                outcome.finalizedAt,
                outcome.challengeCommitment, // Once the outcome is finalized,
                updatedAllocation,
                outcome.token
            );
    }

    function moveAuthorized(
        Commitment.CommitmentStruct memory _commitment,
        Signature memory signature
    ) public pure returns (bool) {
        return
            _commitment.mover() ==
                recoverSigner(abi.encode(_commitment), signature.v, signature.r, signature.s);
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        if (a <= b) {
            return a;
        }

        return b;
    }

    function recoverSigner(bytes memory _d, uint8 _v, bytes32 _r, bytes32 _s)
        public
        pure
        returns (address)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 h = keccak256(_d);

        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, h));

        address a = ecrecover(prefixedHash, _v, _r, _s);

        return (a);
    }

}
