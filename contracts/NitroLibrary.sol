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

   
    function reduce(
        Outcome.SingleAssetOutcome memory outcome,
        address recipient,
        uint256 amount,
        address token
    ) public pure returns (Outcome.SingleAssetOutcome memory) {
        // TODO only reduce entries corresponding to token argument
        Outcome.SingleAssetOutcome memory updatedSingleAssetOutcome = outcome;
        uint256 reduction = 0;
        uint256 remainingAmount = amount;
        for (uint256 i = 0; i < outcome.allocations.length; i++) {
            if (outcome.allocations[i].participant == recipient) {
                // It is technically allowed for a recipient to be listed in the
                // outcome multiple times, so we must iterate through the entire
                // array.
                reduction = reduction.add(min(outcome.allocations[i].amount, remainingAmount));
                remainingAmount = remainingAmount.sub(reduction);
                updatedSingleAssetOutcome.allocations[i].amount = updatedSingleAssetOutcome.allocations[i].amount.sub(reduction);
            }
        }

        return updatedSingleAssetOutcome;
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
