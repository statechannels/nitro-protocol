pragma solidity ^0.5.2;
pragma experimental ABIEncoderV2;
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Commitment.sol";
import "./Rules.sol";

contract IERC20 { // Abstraction of the parts of the ERC20 Interface that we need
    function transfer(address to, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);
}

contract INitroLibrary { // Abstraction of the NitroLibrary contract

    struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
    }

    function recoverSigner(bytes calldata _d, uint8 _v, bytes32 _r, bytes32 _s) external pure returns(address);

    function affords(
        address recipient,
        Outcome.TokenOutcomeItem[] memory allocations,
        uint funding,
        address token
    ) public pure returns (uint256);

    function reprioritize(
        Outcome.AllocationItem[] memory allocations,
        Outcome.Guarantee memory guarantee,
        address token
    ) public pure returns (Outcome.AllocationItem[] memory);

    function moveAuthorized(Commitment.CommitmentStruct calldata _commitment, Signature calldata signature) external pure returns (bool);

   function reduce(
        Outcome.AllocationItem[] memory allocations,
        address recipient,
        uint256 amount,
        address token
    ) public pure returns (Outcome.AllocationItem[] memory);
}

contract NitroAdjudicator {
    using Commitment for Commitment.CommitmentStruct;
    using SafeMath for uint;
    INitroLibrary Library; // Abs

    constructor(address _NitroLibraryAddress) public {
        Library = INitroLibrary(_NitroLibraryAddress); // Abs
    }

    // TODO: Challenge duration should depend on the channel
    uint constant CHALLENGE_DURATION = 5 minutes;

    struct Authorization {
        // Prevents replay attacks:
        // It's required that the participant signs the message, meaning only
        // the participant can authorize a withdrawal.
        // Moreover, the participant should sign the address that they wish
        // to send the transaction from, preventing any replay attack.
        address participant; // the account used to sign commitment transitions
        address destination; // either an account or a channel
        uint amount;
        address sender; // the account used to sign transactions
    }

    struct ConclusionProof {
        Commitment.CommitmentStruct penultimateCommitment;
        INitroLibrary.Signature penultimateSignature; // Abs
        Commitment.CommitmentStruct ultimateCommitment;
        INitroLibrary.Signature ultimateSignature; // Abs
    }

    // **************
    // Storage
    // **************

    mapping(address => mapping(address => uint)) public holdings;

    mapping(address => bytes) public outcomes; // here bytes is abi.encoded Outcome.TokenOutcomeItem[]

    mapping(address => uint256) public finalizationTimes;

    mapping(address => bytes) challenges; // store challengeCommitments here
    // TODO also securely store challenger (so that refutation commitments can be required to have the same signer as the challenger )
    // TODO challenge commitments need to be abi.encoded

    address private constant zeroAddress = address(0);

    // **************
    // ETH and Token Management
    // **************


function deposit(address destination, uint expectedHeld,
 uint amount, address token) public payable {
       if (token == zeroAddress) {
        require(msg.value == amount, "Insufficient ETH for ETH deposit");
        } else {
            IERC20 _token = IERC20(token);
            require(_token.transferFrom(msg.sender,address(this),amount), 'Could not deposit ERC20s');
            }

        uint amountDeposited;
        // This protects against a directly funded channel being defunded due to chain re-orgs,
        // and allow a wallet implementation to ensure the safety of deposits.
        require(
            holdings[destination][token] >= expectedHeld,
            "Deposit: holdings[destination][token] is less than expected"
        );

        // If I expect there to be 10 and deposit 2, my goal was to get the
        // balance to 12.
        // In case some arbitrary person deposited 1 eth before I noticed, making the
        // holdings 11, I should be refunded 1.
        if (holdings[destination][token] == expectedHeld) {
            amountDeposited = amount;
        } else if (holdings[destination][token] < expectedHeld.add(amount)) {
            amountDeposited = expectedHeld.add(amount).sub(holdings[destination][token]);
        } else {
            amountDeposited = 0;
        }
        holdings[destination][token] = holdings[destination][token].add(amountDeposited);
        if (amountDeposited < amount) {
            // refund whatever wasn't deposited.
            if (token == zeroAddress) {
              msg.sender.transfer(amount - amountDeposited); // TODO use safeMath here
          }
            else {
                IERC20 _token = IERC20(token);
                _token.transfer(msg.sender, amount - amountDeposited); // TODO use safeMath here
                // TODO compute amountDeposited *before* calling into erc20 contract, so we only need 1 call not 2
                }
        }
        emit Deposited(destination, amountDeposited, holdings[destination][token]);
    }

    function transferAndWithdraw(address channel,
        address participant,
        address payable destination,
        uint amount,
        address token,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable {
        transfer(channel, participant, amount, token);
        withdraw(participant, destination, amount, token, _v, _r ,_s);
    }

    function withdraw(address participant,
        address payable destination,
        uint amount,
        address token,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public payable {
        require(
            holdings[participant][token] >= amount,
            "Withdraw: overdrawn"
        );
        Authorization memory authorization = Authorization(
            participant,
            destination,
            amount,
            msg.sender
        );

        require(
            Library.recoverSigner(abi.encode(authorization), _v, _r, _s) == participant,
            "Withdraw: not authorized by participant"
        );

        holdings[participant][token] = holdings[participant][token].sub(amount);
        // Decrease holdings before calling to token contract (protect against reentrancy)
        if (token == zeroAddress) {destination.transfer(amount);}
        else {
            IERC20 _token = IERC20(token);
            _token.transfer(destination,amount);
            }

    }

    function transfer(address channel, address destination, uint256 amount, address token) public {
        require(isChannelFinalized(channel),
            "Transfer: channel must be finalized"
        );
        Outcome.TokenOutcomeItem[] memory outcome = Outcome.toTokenOutcome(outcomes[channel]); 
        // Outcome.AllocationItem[] memory allocations = Outcome.getAllocation(assetOutcome.outcomeContent);
        uint256 channelAffordsForDestination = Library.affords(
            destination,
            outcome,
            holdings[channel][token],
            token
        );

        require(
            amount <= channelAffordsForDestination,
            "Transfer: channel cannot afford the requested transfer amount"
        );

        holdings[destination][token] = holdings[destination][token] + amount;
        holdings[channel][token] = holdings[channel][token] - amount;

        outcomes[channel] = abi.encode(Library.reduce(outcome, destination, amount),Outcome.TokenOutcomeItem[]);
    }

    // function transfer(address channel, address destination, uint amount, address token) public {
    //     require(
    //         outcomes[channel].challengeCommitment.guaranteedChannel == zeroAddress,
    //         "Transfer: channel must be a ledger channel"
    //     );
    //     require(
    //         outcomes[channel].finalizedAt <= now,
    //         "Transfer: outcome must be final"
    //     );
    //     require(
    //         outcomes[channel].finalizedAt > 0,
    //         "Transfer: outcome must be present"
    //     );

    //     uint channelAffordsForDestination = Library.affords(destination, outcomes[channel], holdings[channel][token]);

    //     require(
    //         amount <= channelAffordsForDestination,
    //         "Transfer: channel cannot afford the requested transfer amount"
    //     );

    //     holdings[destination][token] = holdings[destination][token] + amount;
    //     holdings[channel][token] = holdings[channel][token] - amount;
    // }


    function concludeAndWithdraw(ConclusionProof memory proof,
        address participant,
        address payable destination,
        uint amount,
        address token,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) public{
        address channelId = proof.penultimateCommitment.channelId();
        if (outcomes[channelId].finalizedAt > now || outcomes[channelId].finalizedAt == 0){
        _conclude(proof);
        } else {
            require(keccak256(abi.encode(proof.penultimateCommitment)) == keccak256(abi.encode(outcomes[channelId].challengeCommitment)),
            "concludeAndWithdraw: channel already concluded with a different proof");
        }
        transfer(channelId,participant, amount, token);
        withdraw(participant,destination, amount, token, _v,_r,_s);
    }

    function claim(address guarantor, address recipient, uint amount, address token) public {
        require(
            isChannelFinalized(guarantor),
            "Claim: channel must be finalized"
        );
        Outcome.TokenOutcomeItem[] memory tokenOutcomes = Outcome.toTokenOutcome(outcomes[guarantor]);

        Outcome.Guarantee memory guarantee;

        for (uint i = 0; i < tokenOutcomes.length; i++) {
            if (tokenOutcomes[i].token == token) {
                Outcome.TypedOutcome memory typedOutcome = Outcome.toTypedOutcome(tokenOutcomes[i].typedOutcome);
                if (Outcome.isGuarantee(typedOutcome)) {
                    guarantee = Outcome.toGuarantee(typedOutcome.data);
                    break; // We found one guarantee for this token, so we don't need to keep looking for more (enforce in client)
                }
            }
        }

        tokenOutcomes = Outcome.toTokenOutcome(outcomes[guarantee.guaranteedChannelId]);

        Outcome.AllocationItem[] memory originalAllocations;

        for (uint i = 0; i < tokenOutcomes.length; i++) {
            if (tokenOutcomes[i].token == token) {
                Outcome.TypedOutcome memory typedOutcome = Outcome.toTypedOutcome(tokenOutcomes[i].typedOutcome);
                if (Outcome.isAllocation(typedOutcome)) {
                    originalAllocations = Outcome.toAllocation(typedOutcome.data);
                    break; // We found one allocation for this token, so we don't need to keep looking for more (enforce in client)
                }
            }
        }
   
        uint funding = holdings[guarantor][token];
        Outcome.AllocationItem[] memory reprioritizedAllocations = Library.reprioritize( // Abs
            originalAllocations,
            guarantee,
            token
        );
        if (Library.affords(recipient, reprioritizedAllocations, funding) >= amount) {
            Outcome.AllocationItem[] memory reducedAllocations = Library.reduce(
                originalAllocations,
                recipient,
                amount,
                token
            );

            Outcome.TypedOutcome memory updatedTypedOutcome = Outcome.TypedOutcome(Outcome.OutcomeType.Allocation, abi.encode(reducedAllocations, Outcome.AllocationItem[]));
            Outcome.TokenOutcomeItem[] memory updatedOutcome = [token,updatedTypedOutcome];
            outcomes[guarantee.guaranteedChannelId] = abi.encode(updatedOutcome,Outcome.TokenOutcomeItem[]); // TODO this assumes only one entry for each token, and worse still overwrites any other tokenOutcomes
            holdings[guarantor][token] = holdings[guarantor][token].sub(amount);
            holdings[recipient][token] = holdings[recipient][token].add(amount);
        } else {
            revert('Claim: guarantor must be sufficiently funded');
        }
    }



    // **********************
    // ForceMove Protocol API
    // **********************

    function conclude(ConclusionProof memory proof) public {
        _conclude(proof);
    }



    function forceMove(
        Commitment.CommitmentStruct memory agreedCommitment,
        Commitment.CommitmentStruct memory challengeCommitment,
        INitroLibrary.Signature[] memory signatures // Abs
    ) public {
        require(
            !isChannelFinalized(agreedCommitment.channelId()),
            "ForceMove: channel must be open"
        );
        require(
            Library.moveAuthorized(agreedCommitment, signatures[0]),
            "ForceMove: agreedCommitment not authorized"
        );
        require(
            Library.moveAuthorized(challengeCommitment, signatures[1]),
            "ForceMove: challengeCommitment not authorized"
        );
        require(
            Rules.validTransition(agreedCommitment, challengeCommitment),
            "ForceMove: Invalid transition"
        );

        address channelId = agreedCommitment.channelId();

        outcomes[channelId] = challengeCommitment.outcome;
        challenges[channelId] = abi.encode(challengeCommitment, Commitment.CommitmentStruct);
        finalizationTimes[channelId] = now + CHALLENGE_DURATION;
        
        emit ChallengeCreated(
            channelId,
            challengeCommitment,
            now + CHALLENGE_DURATION
        );
    }

    function refute(Commitment.CommitmentStruct memory refutationCommitment, INitroLibrary.Signature memory signature) public { // Abs
        address channel = refutationCommitment.channelId();
        require(
            !isChannelFinalized(channel),
            "Refute: channel must be open"
        );

        require(
            Library.moveAuthorized(refutationCommitment, signature),
            "Refute: move must be authorized"
        );

        require(
            Rules.validRefute(outcomes[channel].challengeCommitment, refutationCommitment, signature.v, signature.r, signature.s),
            "Refute: must be a valid refute"
        );

        emit Refuted(channel, refutationCommitment);

        outcomes[channel] = refutationCommitment.outcome; // or delete outcomes[channel] ?
        finalizationTimes[channel] = 0;
    }

    function respondWithMove(Commitment.CommitmentStruct memory responseCommitment, INitroLibrary.Signature memory signature) public { // Abs
        address channel = responseCommitment.channelId();
        require(
            !isChannelFinalized(channel),
            "RespondWithMove: channel must be open"
        );

        require(
            Library.moveAuthorized(responseCommitment, signature),
            "RespondWithMove: move must be authorized"
        );

        require(
            Rules.validRespondWithMove(outcomes[channel].challengeCommitment, responseCommitment, signature.v, signature.r, signature.s),
            "RespondWithMove: must be a valid response"
        );

        emit RespondedWithMove(channel, responseCommitment, signature.v, signature.r, signature.s);

        INitroLibrary.Outcome memory updatedOutcome = INitroLibrary.Outcome( // Abs
            outcomes[channel].destination,
            0,
            responseCommitment,
            responseCommitment.allocation,
            responseCommitment.token
        );
        outcomes[channel] = updatedOutcome;
    }

    function alternativeRespondWithMove(
        Commitment.CommitmentStruct memory _alternativeCommitment,
        Commitment.CommitmentStruct memory _responseCommitment,
        INitroLibrary.Signature memory _alternativeSignature, // Abs
        INitroLibrary.Signature memory _responseSignature // Abs
    )
      public
    {
        address channel = _responseCommitment.channelId();
        require(
            !isChannelFinalized(channel),
            "AlternativeRespondWithMove: channel must be open"
        );

        require(
            Library.moveAuthorized(_responseCommitment, _responseSignature),
            "AlternativeRespondWithMove: move must be authorized"
        );

        uint8[] memory v = new uint8[](2);
        v[0] = _alternativeSignature.v;
        v[1] = _responseSignature.v;

        bytes32[] memory r = new bytes32[](2);
        r[0] = _alternativeSignature.r;
        r[1] = _responseSignature.r;

        bytes32[] memory s = new bytes32[](2);
        s[0] = _alternativeSignature.s;
        s[1] = _responseSignature.s;


        require(
            Rules.validAlternativeRespondWithMove(
                outcomes[channel].challengeCommitment,
                _alternativeCommitment,
                _responseCommitment,
                v,
                r,
                s
            ),
            "RespondWithMove: must be a valid response"
        );

        emit RespondedWithAlternativeMove(_responseCommitment);

        INitroLibrary.Outcome memory updatedOutcome = INitroLibrary.Outcome( // Abs
            outcomes[channel].destination,
            0,
            _responseCommitment,
            _responseCommitment.allocation,
            _responseCommitment.token
        );
        outcomes[channel] = updatedOutcome;
    }

    // ************************
    // ForceMove Protocol Logic
    // ************************

    function _conclude(ConclusionProof memory proof) internal {
        address channelId = proof.penultimateCommitment.channelId();
        require(
            (outcomes[channelId].finalizedAt > now || outcomes[channelId].finalizedAt == 0),
            "Conclude: channel must not be finalized"
        );

        outcomes[channelId] = INitroLibrary.Outcome( // Abs
            proof.penultimateCommitment.destination,
            now,
            proof.penultimateCommitment,
            proof.penultimateCommitment.allocation,
            proof.penultimateCommitment.token
        );
        emit Concluded(channelId);
    }

    function isChannelFinalized(address channel) internal view returns (bool) {
        return outcomes[channel].finalizedAt < now && outcomes[channel].finalizedAt > 0;
    }

    // ****************
    // Events
    // ****************
    event Deposited(address destination, uint256 amountDeposited, uint256 destinationHoldings);

    event ChallengeCreated(
        address channelId,
        Commitment.CommitmentStruct commitment,
        uint256 finalizedAt
    );
    event Concluded(address channelId);
    event Refuted(address channelId, Commitment.CommitmentStruct refutation);
    event RespondedWithMove(address channelId, Commitment.CommitmentStruct response, uint8 v, bytes32 r, bytes32 ss);
    event RespondedWithAlternativeMove(Commitment.CommitmentStruct alternativeResponse);
}