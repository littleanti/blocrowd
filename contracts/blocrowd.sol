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

        c = a * b;
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
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

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
        uint vote;                              // vote (ex. 1 eth = 1 vote)
        uint voted;                             // voted checker
        mapping(address => uint) delegate;      // delegate vote to address
        address[] delegateList;                 // List of address which delegate vote to address
        mapping(address => uint) delegated;     // delegated vote from address
        address[] delegatedList;                // List of address which delegated vote from address
        uint delegatedvote;                     // Total number of delegated vote
        uint delegatedVoted;                    // Total number of delegated voted checker
        uint investorPointer;                   // index of investorList
    }
    
    // struct for voting of each project step
    struct proposal {
        uint voted;         // num of voted in this proposal
        uint favor;         // num of voted favor in this proposal
        uint oppose;        // num of voted oppose in this proposal
        uint peroid;        // peroid of proposal
        uint voteQuorum;    // Quorum of voting (at least)
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
    
    // delegators
    uint public numOfDelegator;
    
    // Number of project proposal (voting step)
    mapping(uint => proposal) public proposals;
    uint public numOfProposal;
    uint public currentProposal;
    uint public currentInstalmented;
    
    // Total fund, total vote, remained fund, soft cap, hard cap and rate of vote (ex. 1 vote = 1 eth)
    uint public totalFund;      // wei
    uint public totalVote;      // 10^18 wei / rate = num of vote
    uint public remainedFund;   // wei
    uint public softCap;        // wei
    uint public hardCap;        // wei
    uint public rate;           // 10^18 wei / rate = num of vote
    uint public projectPeriod;  // unix timestamp
    bool public projectStarted; // project started: true, not yet: false

    // Project Desc.
    string public projectName;

    // Event for Blocrowd related to fund.
    event Invested(address _investor, uint _fund);
    event Refunded(address _investor, uint _fund);
    event Funded(address _creator, uint _fund);
    event InvestSuccessed(address _creator, uint _fund, uint _softCap);
    event InvestFailed(address _creator, uint _fund, uint _softCap);
    // Event for Blocrowd related to vote.
    event ProposalAdded(uint _numOfproposal, uint _proposalIndex, uint _period, uint _voteQuota, uint _instalment);
    event ProposalStarted(address _creator, uint _indexOfProposal, uint _endTime, uint _voteQuota);
    event ProposalEnded(address _creator, uint _indexOfProposal, uint _endTime, uint _voteQuota);
    event Voted(address _investor, uint _indexOfProposal, uint _voted, bool _isFavor, uint _remainedVote);
    event DelegatedVoted(address _delegator, uint _indexOfProposal, uint _voted, bool _isFavor, uint _remainedVote);
    event Delegated(address _investor, address _delegator, uint _amountOfVote);
    event UnDelegated(address _investor, address _delegator, uint _amountOfVote);
    event EndProject(address _creator, uint _totalFund, uint _numOfProposal, uint _numOfInvestor);
    
    /**
     * @dev Constructor to set creator and proposals.
     */
    constructor(address _creator, string _projectName, uint _softCap, uint _hardCap, uint _rate, uint _projectPeriod, uint[] _period, uint[] _voteQuorum, uint[] _voteQuota, uint[] _instalment) public {
        if(_softCap==0) revert();
        if(_hardCap==0) revert();
        if(_rate==0) revert();
        if(_projectPeriod<1 days) revert();
        if(_period.length==0) revert();

        // Set default values;
        projectName = _projectName;
        creator = _creator;
        manager = msg.sender;
        softCap = _softCap;
        hardCap = _hardCap;
        rate = _rate;
        projectPeriod = block.timestamp.add(_projectPeriod); // Unix time (s)
        numOfProposal = _period.length;
        currentProposal = 0;
        projectStarted = false;
        
        // Set proposals
        uint instalmentChecker = 0;
        uint count = 0;
        while(count < numOfProposal)
        {
            if(_voteQuota[count]>10000) revert();   // Max percentage is 100.00 %
            if(_voteQuorum[count]>10000) revert();   // Max percentage is 100.00 %
            proposals[count].peroid = _period[count];
            proposals[count].voteQuorum = _voteQuota[count];
            proposals[count].voteQuota = _voteQuota[count];
            proposals[count].instalment = _instalment[count];
            instalmentChecker = instalmentChecker.add(_instalment[count]);
            count++;
        }
        
        if(instalmentChecker!=10000) revert();  // Total percentage is 100.00 %
    }
    
    //ToDo: need to implement get Functions (numberOfDelegator, get my delegate state) 
   
    /**
     * @dev Function to get total number of investors.
     * @return total number of investors.
     */
    function getTotalInvestor() public view returns (uint total) {
        return numOfInvestor;
    }
    
    /**
     * @dev Function to get total fund.
     * @return total raised fund.
     */
    function getTotalFund() public view returns (uint total) {
        return totalFund;
    }

    /**
     * @dev Function to get invester's fund.
     * @param _invester the address of invester.
     * @return amount of invester's fund.
     */
    function getFundOf(address _invester) public view returns (uint amount) {
        return investors[_invester].fund;
    }

    /**
     * @dev Function to get the number of voted and total vote of current proposal.
     * @param _currentProposal the current proposal phase among proposals.
     * @return amount of voted and total vote of current proposal.
     */
    function getStateVote(uint _currentProposal) public view returns (uint amount, uint total) {
        return (proposals[_currentProposal].voted, totalVote);
    }

    /**
     * @dev Function to get the number of voted favor and oppose vote of current proposal.
     * @param _currentProposal the current proposal phase among proposals.
     * @return amount of voted favor and oppose vote of current proposal.
     */
    function getResultVote(uint _currentProposal) public view returns (uint favor, uint oppose) {
        return (proposals[_currentProposal].favor, proposals[_currentProposal].oppose);
    }

    /**
     * @dev Function to get invester's voted and left vote.
     * @param _invester the address of invester.
     * @return amount of invester's voted and total vote of investor.
     */
    function getVoteOf(address _invester) public view returns (uint amount, uint total) {
        return (investors[_invester].voted, investors[_invester].vote);
    }

    /**
     * @dev Function to send ethereum to creator.
     * @param _amountOfFund the uint of fund amount.
     * @return boolean flag if open success.
     */
    function fund(uint _amountOfFund) internal returns (bool isIndeed) {
        if(_amountOfFund>totalFund) revert();

        // TODO: Calculate Gas fee
        uint gasFee = 210000000000000;
        uint amountOfFund = _amountOfFund.sub(gasFee);

        creator.transfer(amountOfFund);
        
        emit Funded(creator, amountOfFund);
        return true;
    }

    /**
     * @dev Function to refund ethereum to invester.
     * @param _amountOfRefund the uint of refund amount.
     * @return boolean flag if open success.
     */
    function refund(uint _amountOfRefund) internal returns (bool isIndeed) {
        if(_amountOfRefund>totalFund) revert();

        // TODO: Calculate Gas fee
        uint gasFee = 210000000000000;
        uint amountOfRefund = _amountOfRefund.sub(gasFee.mul(numOfInvestor));
        uint perInvestor = 0;

        uint count = 0;
        while(count < numOfInvestor)
        {
            perInvestor = investors[investorList[count]].fund.mul(amountOfRefund).div(totalFund);
            investorList[count].transfer(perInvestor);
            totalFund = totalFund.sub(perInvestor);
            count++;

            emit Refunded(investorList[count], perInvestor);
        }
        
        return true;
    }
    
    /**
     * @dev Function to invest ethereum to _creator
     * @return boolean flag if open success.
     */
    function invest() public payable returns (bool isIndeed) {
        //if(block.timestamp>projectPeriod) revert();
        if(currentProposal!=0) revert();
        if(msg.value==0) revert();
        if(totalFund>hardCap) revert();
        
        // Increase number of Investors when first funding.
        if(investors[msg.sender].fund==0)
        {
            investors[msg.sender].investorPointer = investorList.push(msg.sender)-1;
            numOfInvestor++;
        }
        
        // set fund and vote
        investors[msg.sender].fund = investors[msg.sender].fund.add(msg.value);
        investors[msg.sender].vote = investors[msg.sender].fund.div(rate);
        
        // add total value and vote
        totalFund = totalFund.add(msg.value);
        totalVote = totalVote.add(msg.value.div(rate));
        
        emit Invested(msg.sender, msg.value);
        return true;
    }
    
    /**
     * @dev Function to end invest from _creator
     * @return boolean flag if open success.
     */
    function endInvest() public onlyOwner returns (bool isIndeed) {
        if(currentProposal!=0) revert();
        //if(block.timestamp<=projectPeriod) revert();
        
        // check fund is over softCap or not
        if(totalFund>=softCap)
        {
            // start project
            remainedFund = totalFund;
            // Transfer first instalment to creator, and sub remainedFund
            
            if(fund(totalFund.mul(proposals[currentProposal].instalment).div(10000))) revert();
            remainedFund = remainedFund.sub(totalFund.mul(proposals[currentProposal].instalment).div(10000));
            // Go to next proposal
            currentProposal++;
            // Increase instalmented fund
            currentInstalmented = currentInstalmented.add(proposals[currentProposal].instalment);
            // Start Project 
            projectStarted = true;
            
            emit InvestSuccessed(creator, totalFund, softCap);
            return true;
        }
        else
        {
            // refund fund
            refund(totalFund);
            emit InvestFailed(creator, totalFund, softCap);
            return false;
        }
    }

    /**
     * @dev Create an additional proposal with peroid, and Quota.
     * @param _proposalIndex the uint to set position of new proposal.
     * @param _period the uint to set peroid of voting.
     * @param _voteQuorum the uint to set threshold of voting start.
     * @param _voteQuota the uint to set threshold of voting.
     * @param _instalment the uint to set instalment percentage of proposal.
     * @param _instalmentIndex the uint to sub instalment percentage from proposal that is _instalmentIndex.
     * @return boolean flag if add success.
     */
    function addProposal(uint _proposalIndex, uint _period, uint _voteQuorum, uint _voteQuota, uint _instalment, uint _instalmentIndex) public onlyOwner returns(bool isIndeed) {
        if(_proposalIndex<=currentProposal) revert();
        if(_period==0) revert();
        if(_voteQuorum>10000) revert();
        if(_voteQuota>10000) revert();
        if(_instalment>10000-currentInstalmented) revert();
        
        // shift _proposalIndex to numOfProposal's proposals as 1.
        uint count = numOfProposal;
        while(count > _proposalIndex)
        {
            proposals[count].peroid = proposals[count-1].peroid;
            proposals[count].voteQuorum = proposals[count-1].voteQuorum;
            proposals[count].voteQuota = proposals[count-1].voteQuota;
            if(count-1==_instalmentIndex) proposals[count-1].instalment=proposals[count-1].instalment.sub(_instalment);
            proposals[count].instalment = proposals[count-1].instalment;
         
            count--;
        }
        
        // add new proposal to _proposalIndex.
        proposals[_proposalIndex].peroid = _period;
        proposals[_proposalIndex].voteQuorum = _voteQuorum;
        proposals[_proposalIndex].voteQuota = _voteQuota;
        proposals[_proposalIndex].instalment = _instalment;
    
        numOfProposal = numOfProposal.add(1);
        
        emit ProposalAdded(numOfProposal, _proposalIndex, _period, _voteQuota, _instalment);
        return true;
    }

    /**
     * @dev delegate an vote to evaluator.
     * @param _to the address to delegate my vote of vote.
     * @param _amountOfVote the uint to set the number of vote delegated.
     * @return boolean flag if add success.
     */
    function delegate(address _to, uint _amountOfVote) public returns(bool isIndeed) {
        if(projectStarted!=true) revert();
        if(proposals[currentProposal].started==true) revert();
        if(investors[msg.sender].fund==0) revert();
        if(investors[msg.sender].vote<_amountOfVote) revert();
        
        // add vote to _to and sub vote from msg.sender
        investors[msg.sender].delegate[_to] = investors[msg.sender].delegate[_to].add(_amountOfVote);
        investors[msg.sender].delegateList.push(_to);
        investors[msg.sender].vote = investors[msg.sender].vote.sub(_amountOfVote);

        investors[_to].delegated[msg.sender] = investors[_to].delegated[msg.sender].add(_amountOfVote);
        investors[_to].delegatedList.push(msg.sender);
        investors[_to].delegatedvote = investors[_to].delegatedvote.add(_amountOfVote);

        emit Delegated(msg.sender, _to, _amountOfVote);
        return true;
    }

    /**
     * @dev undelegate an vote to evaluator.
     * @param _to the address to undelegate my vote of vote.
     * @param _amountOfVote the uint to set the number of vote undelegated.
     * @return boolean flag if add success.
     */
    function unDelegate(address _to, uint _amountOfVote) public returns(bool isIndeed) {
        if(projectStarted!=true) revert();
        if(proposals[currentProposal].started==true) revert();
        if(investors[msg.sender].fund==0) revert();
        if(investors[_to].delegated[msg.sender]<_amountOfVote) revert();
        
        // sub vote from _to and add vote to msg.sender
        investors[msg.sender].delegate[_to] = investors[msg.sender].delegate[_to].sub(_amountOfVote);
        investors[msg.sender].vote = investors[msg.sender].vote.add(_amountOfVote);

        investors[_to].delegated[msg.sender] = investors[_to].delegated[msg.sender].sub(_amountOfVote);
        investors[_to].delegatedvote = investors[_to].delegatedvote.sub(_amountOfVote);
        
        emit UnDelegated(msg.sender, _to, _amountOfVote);
        return true;
    }
    
    /**
     * @dev Start voting in proposal in currentProposal.
     * @return boolean flag if add success.
     */
    function startProposal() public onlyOwner returns(bool isIndeed) {
        if(projectStarted!=true) revert();
        if(currentProposal>=numOfProposal) revert();
        if(proposals[currentProposal].started==true) revert();
        
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
    function endProposal() public onlyOwner returns(bool isIndeed) {
        if(projectStarted!=true) revert();
        if(currentProposal>=numOfProposal) revert();
        if(proposals[currentProposal].started!=true) revert();
        //if(block.timestamp<=proposals[currentProposal].peroid) revert();
        
        // End proposal
        proposals[currentProposal].started = false;
        
        // if vote over voteQuorum
        if (proposals[currentProposal].voted < totalVote.mul(proposals[currentProposal].voteQuorum).div(10000))
        {
            // Refund left fund to investors
            refund(remainedFund);
            return false;
        }
        
        // if pass vote
        if(proposals[currentProposal].voted >= totalVote.mul(proposals[currentProposal].voteQuota).div(10000))
        {
            // Transfer instalment to creator, and sub remainedFund
            // Gas fee
            if(fund(totalFund.mul(proposals[currentProposal].instalment).div(10000))) revert();
            remainedFund = remainedFund.sub(totalFund.mul(proposals[currentProposal].instalment).div(10000));

            // Go to next proposal
            currentProposal++;
            
            // Increase instalmented fund
            currentInstalmented = currentInstalmented.add(proposals[currentProposal].instalment);

            emit ProposalEnded(creator, currentProposal-1, proposals[currentProposal-1].voted, proposals[currentProposal-1].peroid);
            return true;
        }
        //if unpass vote
        else
        {
            // Refund left fund to investors
            refund(remainedFund);
            return false;
        }
    }

    /**
     * @dev Vote in proposal in currentProposal.
     * @param _isDelegated the bool to check vote is delegated or not.
     * @param _amountOfVote the uint to set the number of vote voted.
     * @param _isFavor the bool to set favor(true)/oppose(false).
     * @return boolean flag if add success.
     */
    function vote(bool _isDelegated, uint _amountOfVote, bool _isFavor) public returns (bool isIndeed) {
        if(proposals[currentProposal].started!=true) revert();

        if(!_isDelegated)   // vote from investor
        {
            if(investors[msg.sender].vote==0) revert();
            if(_amountOfVote>investors[msg.sender].vote.sub(investors[msg.sender].voted)) revert();
        
            // vote
            if (_isFavor)
                proposals[currentProposal].favor = proposals[currentProposal].voted.add(_amountOfVote);
            else
                proposals[currentProposal].oppose = proposals[currentProposal].voted.add(_amountOfVote);

            proposals[currentProposal].voted = proposals[currentProposal].voted.add(_amountOfVote);
            investors[msg.sender].voted = investors[msg.sender].voted.add(_amountOfVote);
            
            emit Voted(msg.sender, currentProposal, investors[msg.sender].voted, _isFavor, investors[msg.sender].vote.sub(investors[msg.sender].voted));
        }
        else    // vote from delegator
        {
            if(investors[msg.sender].delegatedvote==0) revert();
            if(_amountOfVote>investors[msg.sender].delegatedvote.sub(investors[msg.sender].delegatedVoted)) revert();
        
            // vote
            if (_isFavor)
                proposals[currentProposal].favor = proposals[currentProposal].voted.add(_amountOfVote);
            else
                proposals[currentProposal].oppose = proposals[currentProposal].voted.add(_amountOfVote);

            proposals[currentProposal].voted = proposals[currentProposal].voted.add(_amountOfVote);
            investors[msg.sender].delegatedVoted = investors[msg.sender].delegatedVoted.add(_amountOfVote);
            
            emit DelegatedVoted(msg.sender, currentProposal, investors[msg.sender].delegatedVoted, _isFavor, investors[msg.sender].delegatedvote.sub(investors[msg.sender].delegatedVoted));
        }
        
        return true;
    }
    
    /**
     * @dev End project of creator.
     * @return boolean flag if add success.
     */
    function endProject() public onlyOwner returns (bool isIndeed) {
        if(projectStarted!=true) revert();

        // refund remainedFund to manager (change of fund (ex. less then 1 gwei))
        selfdestruct(manager);
            
        emit EndProject(creator, totalFund, numOfProposal, numOfInvestor);
        return true;
    }
}