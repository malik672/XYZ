// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title XYZContract
 *  A contract that represents the XYZ token with additional features like proposal creation, voting, and role-based access control.
The contract includes these functions:

The constructor which initializes the contract.
grantRole and revokeRole which are used to manage roles.
createProposal which allows privileged roles to create a proposal.
vote which allows users with the VOTER_ROLE to vote on a proposal.
pause and unpause functions that can pause or unpause contract functionality.
It also defines the following variables and constants:

PRIME_ROLE and VOTER_ROLE are the role identifiers.
MAX_ACTIVE_PROPOSALS sets the limit on the maximum number of active proposals.
nftContract is the address of the NFT contract.
oracle is the address of the oracle.
startTime is the timestamp when the contract was created.
proposalCount and activeProposalCount count the total and active proposals respectively.
lastProposalTime is a mapping that keeps track of the last time a user made a proposal.
proposals is a mapping that links an id to a Proposal struct.
Various addresses to manage token distribution like XYZrewards, XYZgrowth, XYZairdrop, seedSale, privateSale, ICO, founder1, founder2, and advisory.
Additionally, the contract defines the Proposal struct, and uses OpenZeppelin's IERC721, ERC20, AccessControl, and Pausable contracts. It emits events when a proposal is created, when a vote is cast, and when roles are granted or revoked.
 */

contract XYZContract is ERC20, AccessControl, ReentrancyGuard, Pausable {
    // Variables
    address public oracle; // Address of the oracle
    uint256 public startTime; // Start time of the contract
    address public XYZrewards; // Address for XYZrewards wallet
    address public XYZgrowth; // Address for XYZgrowth wallet
    address public XYZairdrop; // Address for XYZairdrop wallet
    address public seedSale; // Address for seed sale wallet
    address public privateSale; // Address for private sale wallet
    address public ICO; // Address for ICO sale wallet
    address public founder1; // Address for founder1 wallet
    address public founder2; // Address for founder2 wallet
    address public advisory; // Address for advisory wallet

    // Constants
    bytes32 public constant PRIME_ROLE = keccak256("PRIME_ROLE"); // Role for prime users
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE"); // Role for voter users
    uint256 public constant MAX_SUPPLY = 60_000_000 * 10 ** 18; // Maximum token supply
    uint256 public constant MAX_ACTIVE_PROPOSALS = 5; // Maximum number of active proposals

    // Struct for storing proposal details
    struct Proposal {
        address proposer;
        string description;
        uint256 totalVotes;
        uint256 startTime;
        bool active;
        mapping(address => bool) voters;
    }

    // Proposal count
    uint256 public proposalCount;
    // Active proposal count
    uint256 public activeProposalCount;

    // Mapping from a proposal ID to a Proposal struct
    mapping(uint256 => Proposal) public proposals;

    // The last time a user created a proposal
    mapping(address => uint256) public lastProposalTime;

    // Events
    event ProposalCreated(uint256 proposalId, address proposer, string description, uint256 startTime);
    event VoteCast(uint256 proposalId, address voter);
    event RoleGranted(bytes32 role, address account, address sender);
    event RoleRevoked(bytes32 role, address account, address sender);

    // Constructor
    constructor(address _oracle, address _XYZrewards, address _XYZgrowth, address _XYZairdrop, address _seedSale, address _privateSale, address _ICO, address _founder1, address _founder2, address _advisory) ERC20("XYZ Token", "XYZ") {
        oracle = _oracle;
        startTime = block.timestamp;
        XYZrewards = _XYZrewards;
        XYZgrowth = _XYZgrowth;
        XYZairdrop = _XYZairdrop;
        seedSale = _seedSale;
        privateSale = _privateSale;
        ICO = _ICO;
        founder1 = _founder1;
        founder2 = _founder2;
        advisory = _advisory;

        // Mint initial supply
        uint256 initialSupply = MAX_SUPPLY;
        _mint(address(this), initialSupply);

        // Grant the contract deployer the default admin role: it will be able to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Grant the roles to the addresses
        _setupRole(PRIME_ROLE, oracle);
        _setupRole(VOTER_ROLE, oracle);
    }

    // Function to distribute tokens
    function distributeTokens() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = balanceOf(address(this));

        require(balance > 0, "No tokens to distribute");

        uint256 rewards = balance * 5 / 100; // 5%
        uint256 growth = balance * 20 / 100; // 20%
        uint256 airdrop = balance * 5 / 100; // 5%
        uint256 seed = balance * 10 / 100; // 10%
        uint256 privateSaleShare = balance * 15 / 100; // 15%
        uint256 ico = balance * 15 / 100; // 15%
        uint256 founders = balance * 25 / 100; // 25%
        uint256 advisoryShare = balance * 5 / 100; // 5%

        // Distribute tokens
        _transfer(address(this), XYZrewards, rewards);
        _transfer(address(this), XYZgrowth, growth);
        _transfer(address(this), XYZairdrop, airdrop);
        _transfer(address(this), seedSale, seed);
        _transfer(address(this), privateSale, privateSaleShare);
        _transfer(address(this), ICO, ico);
        _transfer(address(this), founder1, founders / 2); // half of founder's share goes to founder1
        _transfer(address(this), founder2, founders / 2); // half of founder's share goes to founder2
        _transfer(address(this), advisory, advisoryShare);
    }

    /**
     *  Creates a new proposal.
     * @param description Description of the proposal
     */
    function createProposal(string memory description) public nonReentrant onlyRole(PRIME_ROLE) whenNotPaused {
        require(block.timestamp > lastProposalTime[msg.sender].add(1 days), "You have already created a proposal today. Please wait until tomorrow to create a new one.");
        require(activeProposalCount < MAX_ACTIVE_PROPOSALS, "The maximum number of active proposals has been reached. Please wait until a proposal has been finalized to create a new one.");

        uint256 id = proposalCount++;
        Proposal storage proposal = proposals[id];
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp.add(2 days);

        lastProposalTime[msg.sender] = block.timestamp;
        activeProposalCount = activeProposalCount.add(1);

        emit ProposalCreated(id, msg.sender, description, proposal.endTime);
    }

    /**
     *  Allows a user to vote on a proposal.
     * @param id ID of the proposal to vote on
     * @param approve Whether to approve or reject the proposal
     */
    function voteOnProposal(uint256 id, bool approve) public nonReentrant whenNotPaused {
        require(hasRole(VOTER_ROLE, msg.sender), "You do not have the necessary permissions to vote on this proposal.");
        require(block.timestamp <= proposals[id].endTime, "This proposal has already ended.");

        Proposal storage proposal = proposals[id];
        require(!proposal.hasVoted[msg.sender], "You have already voted on this proposal.");
        proposal.hasVoted[msg.sender] = true;
        if (approve) {
            proposal.approvalCount = proposal.approvalCount.add(balanceOf(msg.sender));
        } else {
            proposal.rejectionCount = proposal.rejectionCount.add(balanceOf(msg.sender));
        }
        emit Voted(id, approve, msg.sender);
    }

    /**
     *  Finalizes a proposal.
     * @param id ID of the proposal to finalize
     */
    function finalizeProposal(uint256 id) public nonReentrant whenNotPaused {
        Proposal storage proposal = proposals[id];
        require(block.timestamp > proposal.endTime, "This proposal is still active.");
        require(proposal.approvalCount.add(proposal.rejectionCount) >= totalSupply().div(2), "This proposal has not met the minimum quorum.");

        // Execute the proposal here or schedule its execution if it passed

        activeProposalCount = activeProposalCount.sub(1);
    }

    /**
     *  Checks the balance of an account and assigns roles based on the balance.
     * @param account Address of the account
     */
    function checkBalanceAndAssignRole(address account) internal {
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
     *  Grants a role to an account.
     * @param role Role to grant
     * @param account Address of the account
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(role, account);
        emit RoleGranted(role, account, msg.sender);
    }

    /**
     *  Revokes a role from an account.
     * @param role Role to revoke
     * @param account Address of the account
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(role, account);
        emit RoleRevoked(role, account, msg.sender);
    }

    /**
     *  Pauses the contract.
     */
    function pause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     *  Unpauses the contract.
     */
    function unpause() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     *  Mints tokens periodically based on the elapsed time since contract deployment.
     * Tokens are minted to specific wallets based on the specified addresses.
     */
    function mintTokensPeriodically() external {
        require(msg.sender == oracle, "Only oracle can mint tokens periodically");
        uint256 elapsedYears = (block.timestamp - startTime) / 1 years;
        
        if(elapsedYears > 0){
            _mint(XYZrewards, 1500000 * elapsedYears * 10 ** decimals());
            _mint(XYZgrowth, 900000 * elapsedYears * 10 ** decimals());
            if(elapsedYears <= 3){
                _mint(XYZairdrop, 400000 * elapsedYears * 10 ** decimals());
            }
            startTime += elapsedYears * 1 years;
        }
    }

    /**
     *  Hook that is called before any transfer of tokens.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
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