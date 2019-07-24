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

    mapping(address => SingleAssetOutcome[]] ) outcomes;
    // TODO  ^ don't use this here, but put it in the assetholder contract 
    // e.g. {
    //     0xChannel1 => [
    //      {
    //         0xAssetHolder1,
    //         [{0xAlice, 5}, {0XBob, 3}]
    //     },
    //     {
    //         0xAssetHolder2,
    //         [{0xAlice, 1}, {0XBob, 6}]
    //      }]
    // }
    //     

}
