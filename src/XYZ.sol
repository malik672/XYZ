// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    uint256 public startTime; // Start time of the contract
    uint256 public proposalCount; // Proposal count
    uint256 public activeProposalCount; // Active proposal count
    uint256 public noticeTime = 2 hours;
    uint256 public end = 2 days;
    uint256 public oneYear = 365 days;
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant DECIMALS = 10**18;
    bytes32 public constant PRIME_ROLE = keccak256("PRIME_ROLE"); // Role for prime users
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE"); // Role for voter users
    uint256 public constant MAX_SUPPLY = 60_000_000 * 10 ** 18; // Maximum token supply
    uint256 public constant MAX_ACTIVE_PROPOSALS = 5; // Maximum number of active proposals

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IERC721 public immutable tlp; //address of the nft contract

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

    struct Distributions {
        uint256 rewardsAmount;
        uint256 growthAmount;
        uint256 airdropAmount;
        uint256 seedSaleTokens;
        uint256 privateSaleTokens;
        uint256 ICOtokens;
    }

    Distributions distributes = Distributions({ 
        rewardsAmount: 1_500_000 * DECIMALS ,
        growthAmount: 900_000 * DECIMALS,
        airdropAmount: 400_000 * DECIMALS,
        seedSaleTokens: 1_800_000 * DECIMALS,
        privateSaleTokens: 2_400_000 * DECIMALS,
        ICOtokens: 4_200_000 * DECIMALS
        });

    struct Wallets {
        address founder1;
        address founder2;
        address founder3;
        address founder4;
        address advisory;
        address XYZrewards; // Address for XYZrewards wallet
        address XYZgrowth; // Address for XYZgrowth wallet
        address XYZairdrop; // Address for XYZairdrop wallet
        address seedSale; // Address for seed sale wallet
        address privateSale; // Address for private sale wallet
        address ICO; // Address for ICO sale wallet
    }

    Wallets wallets;

    /*//////////////////////////////////////////////////////////////
                               MAPPINGS
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => Proposal) public proposals; // Mapping from a proposal ID to a Proposal struct
    mapping(address => uint256) public lastProposalTime; // The last time a user created a proposal
    mapping(uint256 => uint256) public notice; //Notice time before each proposal
    mapping(uint256 => bool) validProposal; //checks if a proposal is valid

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(Wallets memory walletAddresses, address _tlp) payable ERC20("XYZ Token", "XYZ") {
        // Grant the contract deployer the default admin role: it will be able to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
 
        //address of the nft contract
        tlp = IERC721(_tlp);

        wallets = Wallets({ 
                founder1: walletAddresses.founder1, 
                founder2: walletAddresses.founder2, 
                founder3: walletAddresses.founder3, 
                founder4: walletAddresses.founder4, 
                advisory: walletAddresses.advisory, 
                XYZrewards: walletAddresses.XYZrewards, 
                XYZgrowth: walletAddresses.XYZgrowth,
                XYZairdrop: walletAddresses.XYZairdrop,
                seedSale: walletAddresses.seedSale,
                privateSale: walletAddresses.privateSale,
                ICO: walletAddresses.ICO 
            });


        // Mint initial supply
        _mint(address(this), 52_200_000 * DECIMALS);

        // Mint tokens for founders and advisory
        _mint(wallets.founder1, 1_500_000 * DECIMALS);
        _mint(wallets.founder2, 1_500_000 * DECIMALS);
        _mint(wallets.founder3, 1_500_000 * DECIMALS);
        _mint(wallets.founder4, 1_500_000 * DECIMALS);
        _mint(wallets.advisory, 1_800_000 * DECIMALS);
    }

    /**
     *  Function to distribute tokens to various wallets.
     */
    function distributeTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = balanceOf(address(this));

        require(balance > 0, "No tokens to distribute");

        // Distribute tokens
        _transfer(address(this), wallets.XYZrewards, distributes.rewardsAmount);
        _transfer(address(this), wallets.XYZgrowth, distributes.growthAmount);
        _transfer(address(this), wallets.XYZairdrop, distributes.airdropAmount);

        // If unsold, transfer to public sale
        if (balance >= distributes.seedSaleTokens) {
            _transfer(address(this), wallets.seedSale, distributes.seedSaleTokens);
        } else {
            _transfer(address(this), wallets.ICO, distributes.seedSaleTokens - balance);
        }

        if (balance >= distributes.privateSaleTokens) {
            _transfer(address(this), wallets.privateSale, distributes.privateSaleTokens);
        } else {
            _transfer(address(this), wallets.ICO, distributes.privateSaleTokens - balance);
        }

        if (balance >= distributes.ICOtokens) {
            _transfer(address(this), wallets.ICO, distributes.ICOtokens);
        }
    }

    /**
     *  Creates a new proposal.
     * @param description Description of the proposal
     */
    function createProposal(string memory description) public nonReentrant onlyRole(PRIME_ROLE) {
        if (lastProposalTime[msg.sender] != 0) {
            require(
                block.timestamp > lastProposalTime[msg.sender] + 1 days,
                "You have already created a proposal today. Please wait until tomorrow to create a new one."
            );
        }
        require(
            balanceOf(msg.sender) >= 30_000 * 10 ** decimals() && tlp.balanceOf(msg.sender) > 0,
            "not enough tokens to vote"
        );

        require(
            activeProposalCount < MAX_ACTIVE_PROPOSALS,
            "The maximum number of active proposals has been reached. Please wait until a proposal has been finalized to create a new one."
        );

        uint256 id = ++proposalCount;
        validProposal[id] = true;
        notice[id] = noticeTime + block.timestamp;
        Proposal storage proposal = proposals[id];
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + end;
        proposal.data = "0x0";
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
            balanceOf(msg.sender) >= 10_000 * 10 ** decimals() && tlp.balanceOf(msg.sender) > 0,
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

        // Execute the proposal here or schedule its execution if it passed

        //execute data in context of present contract
        (bool success, bytes memory data) = address(this).delegatecall(proposal.data);
        require(success, "not successful");
        --activeProposalCount;
        emit ProposalExecuted(id, msg.sender, proposal.data);
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