pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
         // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
         // benefit is lost if 'b' is also tested.
         // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
         if (a == 0) {
                return 0;
         }

         c = a;
         assert(c / a == b);
         return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
         // assert(b > 0); // Solidity automatically throws when dividing by 0
         // uint256 c = a / b;
         // assert(a == b * c + a % b); // There is no case in which this doesn't hold
         return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
         assert(b <= a);
         return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
         c = a + b;
         assert(c >= a);
         return c;
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;
    
    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
         owner = msg.sender;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
         require(msg.sender == owner);
         _;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
         emit OwnershipRenounced(owner);
         owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
         _transferOwnership(_newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address _newOwner) internal {
         require(_newOwner != address(0));
         emit OwnershipTransferred(owner, _newOwner);
         owner = _newOwner;
    }
}

/**
 * @title Blocrowd
 * @dev The crowdfunding system considering investor protection
 */
contract Blocrowd is Ownable {
    using SafeMath for uint;
    
    // struct for investor
    struct investor {
        uint weight;
        uint voted;
        address delegate;
    }
    
    // struct for voting of each project step
    struct proposal {
        uint peroid;
        uint voteQuota;
    }

    address public creator;
    address public chairperson;
    mapping(address => investor) public investors;
    mapping(uint => proposal) public proposals;
    uint public numOfProposal;


    event Voting(address indexed previousOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    /**
     * @dev Constructor to set creator and proposals.
     */
    constructor(address _creator, uint[] _period, uint[] _voteQuota) public {
        creator = _creator;
        
        uint n = _period.length;
        
        numOfProposal = n;
        uint count = 0;
        while (count < n)
        {
            proposals[count].peroid = _period[count];
            proposals[count].voteQuota = _voteQuota[count];
            
            count++;
        }
    }

    /**
     * @dev Create an additional proposal with peroid, and Quota.
     * @param _token the address to get token sell orders.
     * @param _token the address to get token sell orders.
     * @return boolean flag if add success.
     */ 
    function addProposal(uint _period, uint _voteQuota) onlyOwner public {
        numOfProposal = numOfProposal.add(1);
        
        proposals[numOfProposal].peroid = _period;
        proposals[numOfProposal].voteQuota = _voteQuota;

    }

    /// Give $(toVoter) the right to vote on this ballot.
    /// May only be called by $(chairperson).
    function giveRightToVote(address toVoter) public {
        if (msg.sender != chairperson || voters[toVoter].voted) return;
        voters[toVoter].weight = 1;
    }

    /// Delegate your vote to the voter $(to).
    function delegate(address to) public {
        Voter storage sender = voters[msg.sender]; // assigns reference
        if (sender.voted) return;
        while (voters[to].delegate != address(0) && voters[to].delegate != msg.sender)
            to = voters[to].delegate;
        if (to == msg.sender) return;
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegateTo = voters[to];
        if (delegateTo.voted)
            proposals[delegateTo.vote].voteCount += sender.weight;
        else
            delegateTo.weight += sender.weight;
    }

    /// Give a single vote to proposal $(toProposal).
    function vote(uint8 toProposal) public {
        Voter storage sender = voters[msg.sender];
        if (sender.voted || toProposal >= proposals.length) return;
        sender.voted = true;
        sender.vote = toProposal;
        proposals[toProposal].voteCount += sender.weight;
    }

    function winningProposal() public constant returns (uint8 _winningProposal) {
        uint256 winningVoteCount = 0;
        for (uint8 prop = 0; prop < proposals.length; prop++)
            if (proposals[prop].voteCount > winningVoteCount) {
                winningVoteCount = proposals[prop].voteCount;
                _winningProposal = prop;
            }
    }
}

