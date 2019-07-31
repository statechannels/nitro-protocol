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

    address private constant zeroAddress = address(0);

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
