pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;

import './ForceMoveApp.sol';

contract OptimizedForceMove {
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct FixedPart {
        uint256 chainId;
        address[] participants;
        uint256 channelNonce;
        address appDefinition;
        uint256 challengeDuration;
    }

    struct State {
        // participants sign the hash of this
        uint256 turnNum;
        bool isFinal;
        bytes32 channelId; // keccack(chainId,participants,channelNonce)
        bytes32 appPartHash;
        //     keccak256(abi.encode(
        //         fixedPart.challengeDuration,
        //         fixedPart.appDefinition,
        //         variablePart.appData
        //     )
        // )
        bytes32 outcomeHash;
    }

    struct ChannelStorage {
        uint256 turnNumRecord;
        uint256 finalizesAt;
        bytes32 stateHash; // keccak256(abi.encode(State))
        address challengerAddress;
        bytes32 outcomeHash;
    }

    mapping(bytes32 => bytes32) public channelStorageHashes;

    // Public methods:

    function forceMove(
        uint256 turnNumRecord,
        FixedPart memory fixedPart,
        uint256 largestTurnNum,
        ForceMoveApp.VariablePart[] memory variableParts,
        uint8 isFinalCount, // how many of the states are final
        Signature[] memory sigs,
        uint8[] memory whoSignedWhat,
        Signature memory challengerSig
    ) public {
        // Calculate channelId from fixed part
        bytes32 channelId = keccak256(
            abi.encode(fixedPart.chainId, fixedPart.participants, fixedPart.channelNonce)
        );
        ChannelStorage memory channelStorage;
        // ------------
        // REQUIREMENTS
        // ------------

        // Check that the proposed largestTurnNum is larger than or equal to the turnNumRecord that is being committed to
        require(largestTurnNum >= turnNumRecord, 'Stale challenge!');

        // EITHER there is no information stored against channelId at all (OK)
        if (channelStorageHashes[channelId] != bytes32(0)) {
            // OR there is, in which case we must check the channel is still open and that the committed turnNumRecord is correct
            require(
                keccak256(
                        abi.encode(
                            ChannelStorage(turnNumRecord, 0, bytes32(0), address(0), bytes32(0))
                        )
                    ) ==
                    channelStorageHashes[channelId],
                'Channel is not open or turnNum does not match'
            );
        }

        // TODO factor into separate function _validTransitionChain, which returns either false or the stateHashes array

        bytes32[] memory stateHashes = new bytes32[](variableParts.length);
        for (uint256 i = 0; i < variableParts.length; i++) {
            stateHashes[i] = keccak256(
                abi.encode(
                    State(
                        largestTurnNum + i - variableParts.length + 1, // turnNum
                        i > variableParts.length - isFinalCount, // isFinal
                        channelId,
                        keccak256(
                            abi.encode(
                                fixedPart.challengeDuration,
                                fixedPart.appDefinition,
                                variableParts[i].appData
                            )
                        ),
                        keccak256(abi.encode(variableParts[i].outcome))
                    )
                )
            );
            if (i + 1 != variableParts.length) {
                // no transition from final state
                require(
                    _validTransition(
                        fixedPart.participants.length, // nParticipants
                        [
                            i > variableParts.length - isFinalCount,
                            i + 1 > variableParts.length - isFinalCount
                        ], // [a.isFinal, b.isFinal]
                        [variableParts[i], variableParts[i + 1]], // [a,b]
                        largestTurnNum + i - variableParts.length + 2, // b.turnNum
                        fixedPart.appDefinition
                    )
                ); // reason string not necessary (called function will provide reason for reverting)
            }
        }

        // check the supplied states are supported by n signatures
        require(
            _validSignatures(
                largestTurnNum,
                fixedPart.participants,
                stateHashes,
                sigs,
                whoSignedWhat
            ),
            'Invalid signatures'
        );

        // check that the forceMove is signed by a participant and store their address
        bytes32 msgHash = keccak256(
            abi.encode(
                largestTurnNum,
                channelId,
                'forceMove' // Express statement of intent to forceMove this channel to this turnNum
            )
        );
        address challenger = _recoverSigner(
            msgHash,
            challengerSig.v,
            challengerSig.r,
            challengerSig.s
        );
        require(
            _isAddressInArray(challenger, fixedPart.participants),
            'Challenger is not a participant'
        );

        // ------------
        // EFFECTS
        // ------------

        channelStorage = ChannelStorage(
            largestTurnNum,
            now + fixedPart.challengeDuration,
            stateHashes[variableParts.length - 1],
            challenger,
            keccak256(abi.encode(variableParts[variableParts.length - 1].outcome))
        );

        emit ForceMove(channelId, now + fixedPart.challengeDuration, largestTurnNum, challenger); // TODO what else should go in here?

        channelStorageHashes[channelId] = keccak256(abi.encode(channelStorage));

    }

    function respond(
        uint256 turnNumRecord,
        uint256 finalizesAt,
        address challenger,
        bool[2] memory isFinalAB,
        FixedPart memory fixedPart,
        ForceMoveApp.VariablePart[2] memory variablePartAB,
        // variablePartAB[0] = challengeVariablePart
        // variablePartAB[1] = responseVariablePart
        Signature memory sig
    ) public {
        // Calculate channelId from fixed part
        bytes32 channelId = keccak256(
            abi.encode(fixedPart.chainId, fixedPart.participants, fixedPart.channelNonce)
        );

        bytes32 challengeOutcomeHash = keccak256(abi.encode(variablePartAB[0].outcome));
        bytes32 responseOutcomeHash = keccak256(abi.encode(variablePartAB[1].outcome));
        bytes32 challengeStateHash = keccak256(
            abi.encode(
                State(
                    turnNumRecord,
                    isFinalAB[0],
                    channelId,
                    keccak256(
                        abi.encode(
                            fixedPart.challengeDuration,
                            fixedPart.appDefinition,
                            variablePartAB[0].appData
                        )
                    ),
                    challengeOutcomeHash
                )
            )
        );
        bytes32 responseStateHash = keccak256(
            abi.encode(
                State(
                    turnNumRecord + 1,
                    isFinalAB[1],
                    channelId,
                    keccak256(
                        abi.encode(
                            fixedPart.challengeDuration,
                            fixedPart.appDefinition,
                            variablePartAB[1].appData
                        )
                    ),
                    responseOutcomeHash
                )
            )
        );

        // requirements

        require(now < finalizesAt, 'Response too late!');

        require(
            keccak256(
                    abi.encode(
                        ChannelStorage(
                            turnNumRecord,
                            finalizesAt,
                            challengeStateHash,
                            challenger,
                            challengeOutcomeHash
                        )
                    )
                ) ==
                channelStorageHashes[channelId],
            'Challenge State does not match stored version'
        );

        require(
            _recoverSigner(responseStateHash, sig.v, sig.r, sig.s) ==
                fixedPart.participants[(turnNumRecord + 1) % fixedPart.participants.length],
            'Response not signed by authorized mover'
        );

        require(
            _validTransition(
                fixedPart.participants.length,
                isFinalAB,
                variablePartAB,
                turnNumRecord + 1,
                fixedPart.appDefinition
            ) // reason string is not required (_validTransition never returns false, only reverts with its own reason)
        );

        // effects

        // clear the challenge:
        ChannelStorage memory channelStorage = ChannelStorage(
            turnNumRecord + 1,
            0,
            bytes32(0),
            address(0),
            bytes32(0)
        );
        channelStorageHashes[channelId] = keccak256(abi.encode(channelStorage));
    }

    // Internal methods:

    function _isAddressInArray(address suspect, address[] memory addresses)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (suspect == addresses[i]) {
                return true;
            }
        }
        return false;
    }

    function _validSignatures(
        uint256 largestTurnNum,
        address[] memory participants,
        bytes32[] memory stateHashes,
        Signature[] memory sigs,
        uint8[] memory whoSignedWhat // whoSignedWhat[i] is the index of the state in stateHashes that was signed by participants[i]
    ) internal pure returns (bool) {
        uint256 nParticipants = participants.length;
        uint256 nStates = stateHashes.length;

        require(
            _acceptableWhoSignedWhat(whoSignedWhat, largestTurnNum, nParticipants, nStates),
            'Unacceptable whoSignedWhat array'
        );
        for (uint256 i = 0; i < nParticipants; i++) {
            address signer = _recoverSigner(
                stateHashes[whoSignedWhat[i]],
                sigs[i].v,
                sigs[i].r,
                sigs[i].s
            );
            if (signer != participants[i]) {
                return false;
            }
        }
        return true;
    }

    function _acceptableWhoSignedWhat(
        uint8[] memory whoSignedWhat,
        uint256 largestTurnNum,
        uint256 nParticipants,
        uint256 nStates
    ) internal pure returns (bool) {
        require(
            whoSignedWhat.length == nParticipants,
            '_validSignatures: whoSignedWhat must be the same length as participants'
        );
        for (uint256 i = 0; i < nParticipants; i++) {
            uint256 offset = (nParticipants + largestTurnNum - i) % nParticipants;
            // offset is the difference between the index of participant[i] and the index of the participant who owns the largesTurnNum state
            // the additional nParticipants in the dividend ensures offset always positive
            if (whoSignedWhat[i] + offset < nStates - 1) {
                return false;
            }
        }
        return true;
    }

    function _recoverSigner(bytes32 _d, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (address)
    {
        bytes memory prefix = '\x19Ethereum Signed Message:\n32';
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, _d));
        address a = ecrecover(prefixedHash, _v, _r, _s);
        return (a);
    }

    function _validTransition(
        uint256 nParticipants,
        bool[2] memory isFinalAB, // [a.isFinal, b.isFinal]
        ForceMoveApp.VariablePart[2] memory ab, // [a,b]
        uint256 turnNumB,
        address appDefinition
    ) internal pure returns (bool) {
        // a prior check on the signatures for the submitted states implies that the following fields are equal for a and b:
        // chainId, participants, channelNonce, appDefinition, challengeDuration
        // and that the b.turnNum = a.turnNum + 1
        if (isFinalAB[1]) {
            require(
                keccak256(ab[1].outcome) == keccak256(ab[0].outcome),
                'InvalidTransitionError: Cannot move to a final state with a different default outcome'
            );
        } else {
            require(
                !isFinalAB[0],
                'InvalidTransitionError: Cannot move from a final state to a non final state'
            );
            if (turnNumB <= 2 * nParticipants) {
                require(
                    keccak256(ab[1].outcome) == keccak256(ab[0].outcome),
                    'InvalidTransitionError: Cannot change the default outcome during setup phase'
                );
                require(
                    keccak256(ab[1].appData) == keccak256(ab[0].appData),
                    'InvalidTransitionError: Cannot change the appData during setup phase'
                );
            } else {
                require(
                    ForceMoveApp(appDefinition).validTransition(
                        ab[0],
                        ab[1],
                        turnNumB,
                        nParticipants
                    )
                );
                // reason string not necessary (called function will provide reason for reverting)
            }
        }
        return true;
    }

    // events
    event ForceMove(
        bytes32 channelId,
        uint256 expiryTime,
        uint256 turnNumRecord,
        address challenger
    );
}
