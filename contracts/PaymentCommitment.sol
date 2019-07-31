pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

import "./Commitment.sol";
import "./Outcome.sol";

library PaymentCommitment {
    // PaymentGame Commitment Fields
    // (relative to gamestate offset)
    // ==============================
    //
    // No special app attributes required - the
    // resolution in the common state gives us all
    // we need!

    function aBal(Commitment.CommitmentStruct memory _commitment, uint256 i) public pure returns (uint256) {
    return Outcome.getAllocation(Outcome.getAssetOutcome(_commitment.holderAndOutcome[i].assetOutcome).outcomeContent)[0].amount;
    }

    function bBal(Commitment.CommitmentStruct memory _commitment, uint256 i) public pure returns (uint256) {
    return Outcome.getAllocation(Outcome.getAssetOutcome(_commitment.holderAndOutcome[i].assetOutcome).outcomeContent)[1].amount;
    }

    function indexOfMover(Commitment.CommitmentStruct memory _commitment)
        public
        pure
        returns (uint8)
    {
        return uint8(_commitment.turnNum % 2);
    }
}
