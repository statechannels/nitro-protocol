pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Commitment.sol";
import "./Rules.sol";
import "./Outcome.sol";

contract NitroLibrary {
    using Commitment for Commitment.CommitmentStruct;
    using SafeMath for uint;
    
    struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
    }

    address private constant zeroAddress = address(0);


    function reprioritize(
        Outcome.AllocationItem[] memory allocations,
        Outcome.Guarantee memory guarantee
    ) public pure returns (Outcome.AllocationItem[] memory) {
        Outcome.AllocationItem[] memory newAllocations = new Outcome.AllocationItem[](guarantee.destinations.length);
        for (uint256 aIdx = 0; aIdx < allocations.length; aIdx++) {
            for (uint256 gIdx = 0; gIdx < guarantee.destinations.length; gIdx++) {
                if (guarantee.destinations[gIdx] == allocations[aIdx].destination) {
                    newAllocations[gIdx] = allocations[aIdx];
                    break;
                }
            }
        }
        return newAllocations;
    }

    function affords(
        address recipient,
        Outcome.AllocationItem[] memory allocations,
        uint funding
    ) public pure returns (uint256) {
        uint result = 0;
        uint remainingFunding = funding;

        for (uint j = 0; j < allocations.length; j++){
            if (allocations[j].destination == recipient) {
            result = result.add(min(allocations[j].amount, remainingFunding));
            }
            if (remainingFunding > allocations[j].amount){
                remainingFunding = remainingFunding.sub(allocations[j].amount);
            }else{
                remainingFunding = 0;
            }
        }
        return result;
    }

   function reduce(
        Outcome.AllocationItem[] memory allocations,
        address recipient,
        uint256 amount
    ) public pure returns (Outcome.AllocationItem[] memory) {
        uint256 reduction = 0;
        uint256 remainingAmount = amount;
        Outcome.AllocationItem[] memory updatedAllocations = allocations;
        for (uint256 j = 0; j < allocations.length; j++) {
            if (allocations[j].destination == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                reduction = reduction.add(min(allocations[j].amount, remainingAmount));
                remainingAmount = remainingAmount.sub(reduction);
                updatedAllocations[j].amount = updatedAllocations[j].amount.sub(reduction);
            }
        }
        return updatedAllocations;
    }



    function moveAuthorized(Commitment.CommitmentStruct memory _commitment, Signature memory signature) public pure returns (bool){
        return _commitment.mover() == recoverSigner(
            abi.encode(_commitment),
            signature.v,
            signature.r,
            signature.s
        );
    }

    function min(uint a, uint b) public pure returns (uint) {
        if (a <= b) {
            return a;
        }

        return b;
    }

    function recoverSigner(bytes memory _d, uint8 _v, bytes32 _r, bytes32 _s) public pure returns(address) {
    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    bytes32 h = keccak256(_d);

    bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, h));

    address a = ecrecover(prefixedHash, _v, _r, _s);

    return(a);
    }

}
