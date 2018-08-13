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
        uint fund;                              // funded eth
        uint weight;                            // vote (ex. 1 eth = 1 vote)
        uint voted;                             // voted checker
        mapping(address => uint) delegated;     // delegated vote
        address[] delegatedList;                // List of address which delegates vote to me
        uint investorPointer;                   // index of investorList
    }
    
    // struct for voting of each project step
    struct proposal {
        uint voted;         // num of voted in this proposal
        uint peroid;        // peroid of proposal
        uint voteQuota;     // Quota of voting (at least, threshold)
        bool started;       // started: true, not yet/end: false
    }

    // Creator and manager
    address public creator;
    address public manager;
    
    // investors
    mapping(address => investor) public investors;
    address[] investorList;
    uint public numOfInvestor;
    
    // Number of project proposal (voting step)
    mapping(uint => proposal) public proposals;
    uint public numOfProposal;
    uint public currentProposal;
    
    // Soft cap and rate of vote (ex. 1 vote = 1 eth)
    uint public softCap;
    uint public rate;

    // Event for Blocrowd related to fund.
    event Invested(address _investor, uint _fund);
    event Refunded(address _investor, uint _fund);
    // Event for Blocrowd related to vote.
    event ProposalAdded(uint _numOfproposal, uint _period, uint _voteQuota);
    event ProposalStarted(address _creator, uint _indexOfProposal, uint _endTime, uint _voteQuota);
    event ProposalEnded(address _creator, uint _indexOfProposal, uint _endTime, uint _voteQuota);
    event Voted(address indexed previousOwner);
    event Delegated(address _investor, uint _delegator, uint _amountOfWeight);
    
    /**
     * @dev Constructor to set creator and proposals.
     */
    constructor(address _creator, uint _softCap, uint _rate, uint[] _period, uint[] _voteQuota) public {
        // Set default values;
        creator = _creator;
        softCap = _softCap;
        rate = _rate;
        numOfProposal = _period.length;
        
        // Set proposals
        uint n = numOfProposal;
        uint count = 0;
        while (count < n)
        {
            proposals[count].peroid = _period[count];
            proposals[count].voteQuota = _voteQuota[count];
            count++;
        }
    }
    
    /**
     * @dev Function to invest ethereum to _creator
     * @param _creator the address of creator.
     * @return boolean flag if open success.
     */
    function invest(address _creator) payable public returns (bool isIndeed) {
        if(msg.value==0) revert();
        if(_creator!=creator) revert();
        
        // Increase number of Investors when first funding.
        if (investors[msg.sender].fund==0)
        {
            investors[msg.sender].investorPointer = investorList.push(msg.sender)-1;
            numOfInvestor++;
        }
        
        investors[msg.sender].fund = investors[msg.sender].fund.add(msg.value);
        investors[msg.sender].weight = investors[msg.sender].fund.mul(rate);
        
        emit Invested(msg.sender, msg.value);
        return true;
    }
    
    /**
     * @dev Function to refund ethereum to invester.
     * @param _creator the address of creator.
     * @return boolean flag if open success.
     */
    function refund(address _creator) public returns (bool isIndeed) {
        if(_creator!=creator) revert();
        
        uint count = 0;
        while (count < numOfInvestor)
        {
            if (!investorList[count].send(investors[investorList[count]].fund)) revert();
            count++;
        }

        emit Refunded(investorList[count], investors[investorList[count]].fund);
        return true;
    }

    /**
     * @dev Create an additional proposal with peroid, and Quota.
     * @param _period the uint to set peroid of voting.
     * @param _voteQuota the uint to set threshold of voting.
     * @return boolean flag if add success.
     */ 
    function addProposal(uint _period, uint _voteQuota) onlyOwner public returns(bool isIndeed) {
        if(_period==0) revert();
        if(_voteQuota>100) revert();
        
        numOfProposal = numOfProposal.add(1);
        
        proposals[numOfProposal].peroid = _period;
        proposals[numOfProposal].voteQuota = _voteQuota;
        
        emit ProposalAdded(numOfProposal, _period, _voteQuota);
        return true;
    }

    /**
     * @dev delegate an vote to evaluator.
     * @param _to the address to delegate my weight of vote.
     * @param _amountOfWeight the uint to set the number of weight delegated.
     * @return boolean flag if add success.
     */ 
    function delegate(address _to, uint _amountOfWeight) public returns(bool isIndeed) {
        if (investors[msg.sender].weight<_amountOfWeight) revert();
        if (investors[_to].fund==0) revert();
        
        // add weight to _to and sub weight from msg.sender
        investors[_to].delegated[msg.sender] = investors[_to].delegated[msg.sender].add(_amountOfWeight);
        investors[_to].delegatedList.push(msg.sender);
        investors[msg.sender].weight = investors[msg.sender].weight.sub(_amountOfWeight);
        
        emit Delegated(msg.sender, _to, _amountOfWeight);
        return true;
    }
    
    /**
     * @dev Start voting in proposal x.
     * @return boolean flag if add success.
     */ 
    function startProposal() onlyOwner public returns(bool isIndeed) {
        if(currentProposal>=numOfProposal) revert();
        
        // Start proposal
        proposals[currentProposal].started = true;

        // Set end time
        proposals[currentProposal].peroid = block.timestamp + proposals[currentProposal].peroid;
        
        emit ProposalStarted(creator, currentProposal, proposals[currentProposal].voteQuota, proposals[currentProposal].peroid);
        return true;
    }
    
    /**
     * @dev End voting in proposal x.
     * @return boolean flag if add success.
     */ 
    function endProposal() onlyOwner public returns(bool isIndeed) {
        if(currentProposal>=numOfProposal) revert();
        if(block.timestamp<=proposals[currentProposal].peroid) revert();
        
        // End proposal
        proposals[currentProposal].started = false;
        
        // go to next proposal 
        currentProposal++;

        emit ProposalEnded(creator, currentProposal-1, proposals[currentProposal-1].voted, proposals[currentProposal-1].peroid);
        return true;
    }
            
    // struct for voting of each project step
    struct proposal {
        uint peroid;        // peroid of proposal
        uint voteQuota;     // Quota of voting (at least, threshold)
    }

    // Creator and manager
    address public creator;
    address public manager;
    
    // investors
    mapping(address => investor) public investors;
    address[] investorList;
    uint public numOfInvestor;
    
    // Number of project proposal (voting step)
    mapping(uint => proposal) public proposals;
    uint public numOfProposal;
    uint public currentProposal;
        
        
        
        
        numOfProposal = numOfProposal.add(1);
        
        proposals[numOfProposal].peroid = _period;
        proposals[numOfProposal].voteQuota = _voteQuota;
        
        emit ProposalAdded(numOfProposal, _period, _voteQuota);
        return true;
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

