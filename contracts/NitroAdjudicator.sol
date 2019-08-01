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
        Outcome.AllocationItem[] memory allocations,
        uint funding
    ) public pure returns (uint256);

    function reprioritize(
        Outcome.AllocationItem[] memory allocations,
        Outcome.Guarantee memory guarantee
    ) public pure returns (Outcome.AllocationItem[] memory);

    function moveAuthorized(Commitment.CommitmentStruct calldata _commitment, Signature calldata signature) external pure returns (bool);

   function reduce(
        Outcome.AllocationItem[] memory allocations,
        address recipient,
        uint256 amount
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

    mapping(address => mapping(address => uint)) public holdings;  // indices are [address][token]

    mapping(address => mapping(address => bytes)) public outcomes; // indices are [address][token]
    // here bytes is abi.encoded Outcome.TypedOutcome

    mapping(address => mapping(address => uint256)) public finalizationTimes; // indices are [address][token]

    mapping(address => bytes) challenges; // store challengeCommitments here
    // here byted is abi.encoded Commitment.CommitmentStruct

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
        Outcome.TypedOutcome memory typedOutcome = Outcome.toTypedOutcome(outcomes[channel][token]); 
        // from this point on token has been specified
        require(Outcome.isAllocation(typedOutcome),'Transfer: channel must not be a guarantor');
        Outcome.AllocationItem[] memory allocations = Outcome.toAllocation(typedOutcome.data);

        uint256 channelAffordsForDestination = Library.affords(
            destination,
            allocations,
            holdings[channel][token]
        );

        require(
            amount <= channelAffordsForDestination,
            "Transfer: channel cannot afford the requested transfer amount"
        );

        holdings[destination][token] = holdings[destination][token] + amount;
        holdings[channel][token] = holdings[channel][token] - amount;


        Outcome.AllocationItem[] memory newAllocations = Library.reduce(allocations, destination, amount);
        _setAllocationOutcome(channel, newAllocations, token);
    }

    function _setAllocationOutcome(address channel, Outcome.AllocationItem[] memory newAllocations, address token) internal {
        Outcome.TypedOutcome memory newTypedOutcome = Outcome.TypedOutcome(Outcome.OutcomeType.Allocation, abi.encode(newAllocations, Outcome.AllocationItem[]));
        outcomes[channel][token] = abi.encode(newTypedOutcome, Outcome.TypedOutcome);
    }

    function _setGuaranteeOutcome(address channel, Outcome.AllocationItem[] memory newGuarantee, address token) internal {
        Outcome.TypedOutcome memory newTypedOutcome = Outcome.TypedOutcome(Outcome.OutcomeType.Guarantee, abi.encode(newGuarantee, Outcome.Guarantee));
        outcomes[channel][token] = abi.encode(newTypedOutcome, Outcome.TypedOutcome);
    }


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
        if (!isChannelFinalized(channelId)){
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
        Outcome.TypedOutcome memory typedOutcome = Outcome.toTypedOutcome(outcomes[guarantor][token]);
        // from this point on token has been specified
        require(Outcome.isGuarantee(typedOutcome),'Claim: must be a guarantor');
        Outcome.Guarantee memory guarantee = Outcome.toGuarantee(typedOutcome.data);


       typedOutcome = Outcome.toTypedOutcome(outcomes[guarantee.guaranteedChannelId][token]); 
        // from this point on token has been specified
        require(Outcome.isAllocation(typedOutcome),'Claim: guaranteed channel must not be a guarantor');
        Outcome.AllocationItem[] memory originalAllocations = Outcome.toAllocation(typedOutcome.data);
   
        uint funding = holdings[guarantor][token];

        Outcome.AllocationItem[] memory reprioritizedAllocations = Library.reprioritize( // Abs
            originalAllocations,
            guarantee
        );
        if (Library.affords(recipient, reprioritizedAllocations, funding) >= amount) {
            Outcome.AllocationItem[] memory reducedAllocations = Library.reduce(
                originalAllocations,
                recipient,
                amount
            );

            holdings[guarantor][token] = holdings[guarantor][token].sub(amount);
            holdings[recipient][token] = holdings[recipient][token].add(amount);
            _setAllocationOutcome(guarantee.guaranteedChannelId, reducedAllocations, token);
        } else {
            revert('Claim: guarantor must be sufficiently funded');
        }
    }



    // **********************
    // ForceMove Protocol API
    // **********************

    function conclude(ConclusionProof memory proof) public {
        _conclude(proof);
         // TODO add checks on this method
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
        challenges[channel] = abi.encode(refutationCommitment,Commitment.CommitmentStruct);
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

        outcomes[channel] = responseCommitment.outcome; // or delete outcomes[channel] ?
        challenges[channel] = abi.encode(responseCommitment,Commitment.CommitmentStruct);
        finalizationTimes[channel] = 0;
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

        outcomes[channel] = _responseCommitment.outcome; // or delete outcomes[channel] ?
        challenges[channel] = abi.encode(_responseCommitment,Commitment.CommitmentStruct);
        finalizationTimes[channel] = 0;
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

        outcomes[channelId] = proof.penultimateCommitment.outcome; // or delete outcomes[channel] ?
        challenges[channelId] = abi.encode(proof.penultimateCommitment,Commitment.CommitmentStruct);
        finalizationTimes[channelId] = 0;

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