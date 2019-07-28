pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

import "./Commitment.sol";
import "./PaymentCommitment.sol";

contract PaymentApp {
    using Commitment for Commitment.CommitmentStruct;
    using PaymentCommitment for Commitment.CommitmentStruct;
    function validTransition(
        Commitment.CommitmentStruct memory _old,
        Commitment.CommitmentStruct memory _new
    ) public pure returns (bool) {
        // TODO handle a new outcome of different length to the old outcome
        for (uint256 i = 0;i<_old.outcome.length; i++) {
        // conserve total balance
        require(
            _old.aBal(i) + _old.bBal(i) == _new.aBal(i) + _new.bBal(i),
            "PaymentApp: The balance must be conserved."
        );
        

        // can't take someone else's funds by moving
        if (_new.indexOfMover() == 0) {
            // a is moving
            require(
                _new.aBal(i) <= _old.aBal(i),
                "PaymentApp: Player A cannot increase their own allocation."
            ); // so aBal can't increase
        } else {
            // b is moving
            require(
                _new.bBal(i) <= _old.bBal(i),
                "PaymentApp: Player B cannot increase their own allocation."
            ); // so aBal can't increase
        }
        }

        return true;
    }
}
