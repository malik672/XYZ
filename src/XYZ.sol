// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract XYZContract is ERC20, AccessControl, ReentrancyGuard {
    

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event ProposalCreated(uint256 proposalId, address proposer, string description, uint256 startTime);
    event VoteCast(uint256 proposalId, address voter, bool approve);
    event ProposalExecuted(uint256 proposalId, address _executor, bytes data);

    /*//////////////////////////////////////////////////////////////
                               STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public XYZrewards; // Address for XYZrewards wallet
    address public XYZgrowth; // Address for XYZgrowth wallet
    address public XYZairdrop; // Address for XYZairdrop wallet
    address public seedSale; // Address for seed sale wallet
    address public privateSale; // Address for private sale wallet
    address public ICO; // Address for ICO sale wallet
    address public founder1; // Address for founder1 wallet
    address public founder2; // Address for founder2 wallet
    address public founder3; // Address for founder3 wallet
    address public founder4; // Addresss for founder 4 wallet
    address public advisory; // Address for advisory wallet
    uint256 public startTime; // Start time of the contract
    uint256 public proposalCount; // Proposal count
    uint256 public activeProposalCount; // Active proposal count
    IERC721 public ERC721;
    uint256 public noticeTime = 2 hours; // Notice Time
    uint256 public end = 2 days; //End days


    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    bytes32 public constant PRIME_ROLE = keccak256("PRIME_ROLE"); // Role for prime users
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE"); // Role for voter users
    uint256 public constant MAX_SUPPLY = 60_000_000 * 10 ** 18; // Maximum token supply
    uint256 public constant MAX_ACTIVE_PROPOSALS = 5; // Maximum number of active proposals

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    address public immutable tlp; //address of the nft contract

    /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct Proposal {
        uint256 totalVotes; //Total votes for the proposal
        uint256 startTime; //Starting time of the proposal
        uint256 endTime; //time the proposal gets to end
        uint256 approvalCount; //amount of voters that voted for the proposal
        uint256 rejectionCount; //amount of voters that rejected the proposal
        address proposer; //proposer starter
        bool active; //checks if the proposal is still active
        string description; //description of the proposal
        bytes data; //data to be executed on the contract
        mapping(address => bool) hasVoted; //checks if the user has voted
    }

    /*//////////////////////////////////////////////////////////////
                               MAPPINGS
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => Proposal) public proposals; // Mapping from a proposal ID to a Proposal struct
    mapping(address => uint256) public lastProposalTime; // The last time a user created a proposal
    mapping(uint256 => uint256) public notice; //Notice time before each proposal
    mapping(uint256 => bool) validProposal; //checks if a proposal is valid
    mapping(uint256 => mapping(address => bool)) private hasVoted; // Mapping to track if a user has voted on a proposal

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _XYZrewards,
        address _XYZgrowth,
        address _XYZairdrop,
        address _seedSale,
        address _privateSale,
        address _ICO,
        address _founder1,
        address _founder2,
        address _founder3,
        address _founder4,
        address _advisory,
        address _tlp
    ) payable ERC20("XYZ Token", "XYZ") {
        // Grant the contract deployer the default admin role: it will be able to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        assembly {
            sstore(startTime.slot, timestamp())
            sstore(XYZrewards.slot, _XYZrewards)
            sstore(XYZgrowth.slot, _XYZgrowth)
            sstore(XYZairdrop.slot, _XYZairdrop)
            sstore(seedSale.slot, _seedSale)
            sstore(privateSale.slot, _privateSale)
            sstore(ICO.slot, _ICO)
            sstore(founder1.slot, _founder1)
            sstore(founder2.slot, _founder2)
            sstore(founder3.slot, _founder3)
            sstore(founder4.slot, _founder4)
            sstore(advisory.slot, _advisory)
        }
        //address of the nft contract
        tlp = _tlp;

        //set Nft
        ERC721 = IERC721(tlp);

        // Mint initial supply
        _mint(address(this), MAX_SUPPLY);

        // Mint tokens for founders and advisory
        _mint(founder1, 1500000 * 10 ** 18);
        _mint(founder2, 1500000 * 10 ** 18);
        _mint(founder3, 1500000 * 10 ** 18);
        _mint(founder4, 1500000 * 10 ** 18);
        _mint(advisory, 1_800_000 * 10 ** 18);
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *  Function to distribute tokens to various wallets.
     */
    function distributeTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = balanceOf(address(this));

        require(balance > 0, "No tokens to distribute");

        uint256 rewards = 1_500_000 * 10 ** 18; // 1.5 million tokens
        uint256 growth = 900_000 * 10 ** 18; // 900,000 tokens
        uint256 airdrop = 400_000 * 10 ** 18; // 400,000 tokens

        uint256 seedSaleTokens = 1_800_000 * 10 ** 18;
        uint256 privateSaleTokens = 2_400_000 * 10 ** 18;
        uint256 ICOtokens = 4_200_000 * 10 ** 18;

        // Distribute tokens
        _transfer(address(this), XYZrewards, rewards);
        _transfer(address(this), XYZgrowth, growth);
        _transfer(address(this), XYZairdrop, airdrop);

        // If unsold, transfer to public sale
        if (balance >= seedSaleTokens) {
            _transfer(address(this), seedSale, seedSaleTokens);
        } else {
            _transfer(address(this), ICO, seedSaleTokens - balance);
        }

        if (balance >= privateSaleTokens) {
            _transfer(address(this), privateSale, privateSaleTokens);
        } else {
            _transfer(address(this), ICO, privateSaleTokens - balance);
        }

        if (balance >= ICOtokens) {
            _transfer(address(this), ICO, ICOtokens);
        }
    }

    /**
     *  Creates a new proposal.
     * @param description Description of the proposal
     */
    function createProposal(string memory description, bytes memory data) public nonReentrant onlyRole(PRIME_ROLE) {
        uint256 id = ++proposalCount;
        if (lastProposalTime[msg.sender] != 0) {
            require(
                block.timestamp > lastProposalTime[msg.sender] + 1 days,
                "You have already created a proposal today. Please wait until tomorrow to create a new one."
            );
        }
        require(
            balanceOf(msg.sender) >= 30_000 * 10 ** decimals() && ERC721.balanceOf(msg.sender) > 0,
            "not enough tokens to vote"
        );
        require(!hasVoted[id][msg.sender], "You have already voted on this proposal.");

        require(
            activeProposalCount < MAX_ACTIVE_PROPOSALS,
            "The maximum number of active proposals has been reached. Please wait until a proposal has been finalized to create a new one."
        );
        
        validProposal[id] = true;
        notice[id] = noticeTime + block.timestamp;
        Proposal storage proposal = proposals[id];
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + end;
        proposal.data = data;
        lastProposalTime[msg.sender] = block.timestamp;
        ++activeProposalCount;

        emit ProposalCreated(id, msg.sender, description, proposal.endTime);
    }

    ///@notice this functions allocates votes to user based on token allocation
    function allocateVote() private view returns (uint256 _weight) {
        _weight = (balanceOf(msg.sender) / (10_000 * 10 ** decimals()));
        _weight = _weight > 10 ? 10 : _weight;
    }

    /**
     *  Allows a user to vote on a proposal.
     * @param id ID of the proposal to vote on
     * @param approve Whether to approve or reject the proposal
     */

    function voteOnProposal(uint256 id, bool approve) public nonReentrant {
        require(block.timestamp < proposals[id].endTime, "This proposal has already ended.");
        require(
            balanceOf(msg.sender) >= 10_000 * 10 ** decimals() && ERC721.balanceOf(msg.sender) > 0,
            "not enough tokens to vote"
        );
        require(validProposal[id] == true, "invalid proposal");
        Proposal storage proposal = proposals[id];
        require(!proposal.hasVoted[msg.sender], "You have already voted on this proposal.");
        proposal.hasVoted[msg.sender] = true;
        if (approve) {
            proposal.approvalCount += allocateVote();
        } else {
            proposal.rejectionCount += allocateVote();
        }

        // Mark the user as voted
        hasVoted[id][msg.sender] = true;
        emit VoteCast(id, msg.sender, approve);
    }

    /**
     *  Finalizes a proposal.
     * @param id ID of the proposal to finalize
     */
    function finalizeProposal(uint256 id) public nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) {
        Proposal storage proposal = proposals[id];
        require(validProposal[id] == true, "invalid proposal");
        require(block.timestamp > proposal.endTime, "This proposal is still active.");
        require(proposal.approvalCount > proposal.rejectionCount, "This proposal has not met the minimum quorum.");
        uint256 bal = balanceOf(address(this));

        // Execute the proposal here or schedule its execution if it passed

        //execute data in context of present contract
        (bool success, bytes memory data) = address(this).call{value: 0}(proposal.data);
        require(success, "not successful");
        uint256 bals = balanceOf(address(this));
        --activeProposalCount;
        require(bal == bals, "revert can't move tokens");
        emit ProposalExecuted(id, msg.sender, proposal.data);
    }
 
    //Get votes per proposal
    function getVotesPerProposal(uint _id) view external returns(uint256 _total){

       Proposal storage proposal = proposals[id];
       _total = proposal.totalVotes;
    }

    /**
     *  Checks the balance of an account and assigns roles based on the balance.
     * @param account Address of the account
     */
    function checkBalanceAndAssignRole(address account) public {
        uint256 balance = balanceOf(account);
        if (balance >= 30_000 * 10 ** decimals()) {
            grantRole(PRIME_ROLE, account);
        } else if (balance >= 10_000 * 10 ** decimals()) {
            grantRole(VOTER_ROLE, account);
        } else {
            revokeRole(VOTER_ROLE, account);
            revokeRole(PRIME_ROLE, account);
        }
    }

    /**
     *  Hook that is called before any transfer of tokens.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if (from != address(0)) {
            checkBalanceAndAssignRole(from);
        }
        if (to != address(0)) {
            checkBalanceAndAssignRole(to);
        }
    }

    /**
     *  Hook that is called after any transfer of tokens.
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal override {
        super._afterTokenTransfer(from, to, amount);

        if (from != address(0)) {
            checkBalanceAndAssignRole(from);
        }
        if (to != address(0)) {
            checkBalanceAndAssignRole(to);
        }
    }
}
