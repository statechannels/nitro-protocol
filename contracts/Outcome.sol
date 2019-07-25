pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

library Outcome {

    struct allocation {
        address participant,
        uint amount,
    } 
    // e.g. {0xAlice, 5}
    
    struct SingleAssetOutcome {
        address AssetHolder,
        allocation[] allocations,
    }
    // e.g.
    //      {
    //         0xAssetHolder1,
    //         [{0xAlice, 5}, {0XBob, 3}]
    //     }  
}
