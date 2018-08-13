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
         if(a == 0) {
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
        uint instalment;    // rate of instalment
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
    
    // Total fund, remained fund, soft cap, hard cap and rate of vote (ex. 1 vote = 1 eth)
    uint public totalFund;
    uint public remainedFund;
    uint public softCap;
    uint public hardCap;
    uint public rate;
    uint public projectPeriod;

    // Event for Blocrowd related to fund.
    event Invested(address _investor, uint _fund);
    event Refunded(address _investor, uint _fund);
    event InvestSuccessed(address _creator, uint _fund, uint _softCap);
    event InvestFailed(address _creator, uint _fund, uint _softCap);
    // Event for Blocrowd related to vote.
    event ProposalAdded(uint _numOfproposal, uint _period, uint _voteQuota);
    event ProposalStarted(address _creator, uint _indexOfProposal, uint _endTime, uint _voteQuota);
    event ProposalEnded(address _creator, uint _indexOfProposal, uint _endTime, uint _voteQuota);
    event Voted(address _investor, uint _indexOfProposal, uint _voted, uint _remainedWeight);
    event Delegated(address _investor, uint _delegator, uint _amountOfWeight);
    event EndProject(address _creator, uint _totalFund, uint _numOfProposal, uint _numOfInvestor);
    
    /**
     * @dev Constructor to set creator and proposals.
     */
    constructor(address _creator, uint _softCap, uint _hardCap, uint _rate, uint _projectPeriod, uint[] _period, uint[] _voteQuota, uint[] _instalment) public {
        // Set default values;
        creator = _creator;
        softCap = _softCap;
        hardCap = _hardCap;
        rate = _rate;
        projectPeriod = block.timestamp.add(_projectPeriod);
        numOfProposal = _period.length;
        
        // Set proposals
        uint instalmentChecker = 0;
        uint count = 0;
        while (count < numOfProposal)
        {
            if(_voteQuota[count]>10000) revert();
            proposals[count].peroid = _period[count];
            proposals[count].voteQuota = _voteQuota[count];
            proposals[count].instalment = _instalment[count];
            instalmentChecker = instalmentChecker.add(_instalment[count]);
            count++;
        }
        
        if(instalmentChecker!=10000) revert();
    }
    
    /**
     * @dev Function to refund ethereum to invester.
     * @param _creator the address of creator.
     * @param _amountOfRefund the uint of refund amount.
     * @return boolean flag if open success.
     */
    function refund(address _creator, uint _amountOfRefund) internal returns (bool isIndeed) {
        if(_creator!=creator) revert();
        if(_amountOfRefund>totalFund) revert();
        
        uint count = 0;
        while (count < numOfInvestor)
        {
            if(!investorList[count].send(investors[investorList[count]].fund.mul(_amountOfRefund).div(totalFund))) revert();
            totalFund = totalFund.sub(investors[investorList[count]].fund.mul(_amountOfRefund).div(totalFund));
            count++;
        }
        
        // reset totalFund
        if(!manager.send(totalFund)) revert();
        
        emit Refunded(investorList[count], investors[investorList[count]].fund);
        return true;
    }
    
    /**
     * @dev Function to invest ethereum to _creator
     * @param _creator the address of creator.
     * @return boolean flag if open success.
     */
    function invest(address _creator) payable public returns (bool isIndeed) {
        if(msg.value==0) revert();
        if(_creator!=creator) revert();
        if(totalFund>hardCap) revert();
        
        // Increase number of Investors when first funding.
        if(investors[msg.sender].fund==0)
        {
            investors[msg.sender].investorPointer = investorList.push(msg.sender)-1;
            numOfInvestor++;
        }
        
        // set fund and weight
        investors[msg.sender].fund = investors[msg.sender].fund.add(msg.value);
        investors[msg.sender].weight = investors[msg.sender].fund.mul(rate);
        
        // add total value
        totalFund = totalFund.add(msg.value);
        
        emit Invested(msg.sender, msg.value);
        return true;
    }
    
    /**
     * @dev Function to end invest from _creator
     * @param _creator the address of creator.
     * @return boolean flag if open success.
     */
    function endInvest(address _creator) onlyOwner public returns (bool isIndeed) {
        if(_creator!=creator) revert();
        if(block.timestamp<=projectPeriod) revert();
        
        // check fund is over softCap or not
        if(totalFund>=softCap)
        {
            // start project
            remainedFund = totalFund;
            emit InvestSuccessed(creator, totalFund, softCap);
            return true;
        }
        else
        {
            // refund fund
            refund(creator, totalFund);
            emit InvestFailed(creator, totalFund, softCap);
            return false;
        }
    }

    /**
     * @dev Create an additional proposal with peroid, and Quota.
     * @param _period the uint to set peroid of voting.
     * @param _voteQuota the uint to set threshold of voting.
     * @return boolean flag if add success.
     */ 
    function addProposal(uint _period, uint _voteQuota) onlyOwner public returns(bool isIndeed) {
        //Todo: need to revise add proposal.
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
        if(investors[msg.sender].weight<_amountOfWeight) revert();
        if(investors[_to].fund==0) revert();
        
        // add weight to _to and sub weight from msg.sender
        investors[_to].delegated[msg.sender] = investors[_to].delegated[msg.sender].add(_amountOfWeight);
        investors[_to].delegatedList.push(msg.sender);
        investors[msg.sender].weight = investors[msg.sender].weight.sub(_amountOfWeight);
        
        emit Delegated(msg.sender, _to, _amountOfWeight);
        return true;
    }
    
    /**
     * @dev Start voting in proposal in currentProposal.
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
     * @dev End voting in proposal in currentProposal.
     * @return boolean flag if add success.
     */ 
    function endProposal() onlyOwner public returns(bool isIndeed) {
        if(currentProposal>=numOfProposal) revert();
        if(block.timestamp<=proposals[currentProposal].peroid) revert();
        
        // End proposal
        proposals[currentProposal].started = false;
        
        uint count = 0;
        // if pass vote
        if(proposals[currentProposal].voted >= totalFund.mul(rate).mul(proposals[currentProposal].voteQuota).div(10000))
        {
            // refill weight of investors
            while (count < numOfInvestor)
            {
                investors[investorList[count]].weight = investors[investorList[count]].fund.mul(rate);
                count++;
            }
            
            // send instalment to creator, and sub remainedFund
            creator.send(totalFund.mul(proposals[currentProposal].instalment).div(10000));
            remainedFund = remainedFund.sub(totalFund.mul(proposals[currentProposal].instalment).div(10000));
            
            // go to next proposal 
            currentProposal++;
    
            emit ProposalEnded(creator, currentProposal-1, proposals[currentProposal-1].voted, proposals[currentProposal-1].peroid);
            return true;
        }
        //if unpass vote
        else
        {
            // refund left fund to investors
            refund(creator, remainedFund);
            return false;
        }
    }
            
    /**
     * @dev Vote in proposal in currentProposal.
     * @param _creator the address of the creator.
     * @param _amountOfWeight the uint to set the number of weight voted.
     * @return boolean flag if add success.
     */ 
    function vote(uint _amountOfWeight) public returns (bool isIndeed) {
        //Todo: need to consider Delegated vote.
        if(investors[msg.sender].weight==0) revert();
        if(_amountOfWeight>investors[msg.sender].sub(investors[msg.sender].voted)) revert();
        
        // vote
        proposals[currentProposal].voted = proposals[currentProposal].voted.add(_amountOfWeight);
        investors[msg.sender].voted = investors[msg.sender].voted.add(_amountOfWeight);
        
        emit Voted(msg.sender, currentProposal, investors[msg.sender].voted, investors[msg.sender].weight.sub(investors[msg.sender].voted));
        return true;
    }
    
    /**
     * @dev End project of creator.
     * @return boolean flag if add success.
     */ 
    function endProject() onlyOwner public returns (bool isIndeed) {
        if(!manager.send(remainedFund)) revert();
            
        emit EndProject(creator, totalFund, numOfProposal, numOfInvestor);
        return true;
    }
}
