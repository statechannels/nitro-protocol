pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Commitment.sol";
import "./Rules.sol";

contract NitroLibrary {
    using Commitment for Commitment.CommitmentStruct;
    using SafeMath for uint;
    
    struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
    }

    struct Outcome {
    address[] destination;
    uint256 finalizedAt;
    Commitment.CommitmentStruct challengeCommitment;

    // exactly one of the following two should be non-null
    // guarantee channels
    uint[] allocation;         // should be zero length in guarantee channels

    address[] token;
    }

    address private constant zeroAddress = address(0);


    function reprioritize(
        Outcome.AllocationItem[] memory allocations,
        Outcome.Guarantee memory guarantee,
        address token
    ) public pure returns (Outcome.AllocationItem[] memory) {
        Outcome.AllocationItem[] memory newAllocations = new Outcome.AllocationItem[](guarantee.length);
        for (uint i = 0; i < allocations.length; i++){
            if (allocations[i].token == token) {
                Outcome.AllocationItem[] allocation = Outcome.toAllocation(allocations[i].typedOutcome);
                for (uint256 aIdx = 0; aIdx < allocation.length; aIdx++) {
                    for (uint256 gIdx = 0; gIdx < guarantee.length; gIdx++) {
                        if (guarantee.destinations[gIdx] == allocation[aIdx].destination) {
                            newAllocation[gIdx] = allocation[aIdx];
                            break;
                        }
                    }
                }
            }
        }
        return newAllocations;
    }

    function affords(
        address recipient,
        Outcome.TokenOutcomeItem[] memory allocations,
        uint funding,
        address token
    ) public pure returns (uint256) {
        uint result = 0;
        uint remainingFunding = funding;

        for (uint i = 0; i < allocations.length; i++) {
            if (allocations[i].token == token && Outcome.isAllocation(Outcome.toTypedOutcome(allocations[i].typedOutcome))) {
                Outcome.AllocationItem[] allocation = Outcome.toAllocation(allocations[i].typedOutcome);
                for (uint j = 0; j < allocation.length; j++){
                   if (allocation[j].destination == recipient) {
                    result = result.add(min(allocation[j].amount, remainingFunding));
                   }
                    if (remainingFunding > allocation[j].amount){
                        remainingFunding = remainingFunding.sub(allocation[j].amount);
                    }else{
                        remainingFunding = 0;
                    }
                }
            }
        }

        return result;
    }

   function reduce(
        Outcome.AllocationItem[] memory allocations,
        address recipient,
        uint256 amount,
        address token
    ) public pure returns (Outcome.AllocationItem[] memory) {
        Outcome.AllocationItem[] memory updatedAllocation = allocations;
        uint256 reduction = 0;
        uint256 remainingAmount = amount;
        for (unint i = 0; i < allocations.length; i++){
            Outcome.AllocationItem[] allocation = Outcome.toAllocation(allocations[i].typedOutcome);
            if (allocations[i].token == token) {
                for (uint256 j = 0; j < allocation.length; j++) {
                    if (allocation[j].destination == recipient) {
                        // It is technically allowed for a recipient to be listed in the
                        // outcome multiple times, so we must iterate through the entire
                        // array.
                        reduction = reduction.add(min(allocation[j].amount, remainingAmount));
                        remainingAmount = remainingAmount.sub(reduction);
                        updatedAllocation[j].amount = updatedAllocation[j].amount.sub(reduction);
                    }
                }
            }
        }
        return updatedAllocation;
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