// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TheLoungePass is ERC721, Ownable, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                               STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address public TLPportfolio;
    uint256 public tokenIds;
    address public XYZburn;
    uint256 public currentPrice;
    IERC20 public USDT;

    /*//////////////////////////////////////////////////////////////
                               MAPPINGS
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => uint256) private tokenPrices;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _TLPportfolio, address _XYZburn, address _usdt) payable ERC721("TheLoungePass", "TLP") {
        assembly {
            sstore(TLPportfolio.slot, _TLPportfolio)
            sstore(XYZburn.slot, _XYZburn)
        }
        USDT = IERC20(_usdt);
        currentPrice = 150 * 10 ** 6;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //mints an NFT to the sender
    //User Must Call Approve from the USDT Contract to allow spending
    function mint(address _addr) public onlyOwner {

        //transfers 150 worth of usdt from user address to contract
        // critical error fix = Conversion error of price, was wei should be 1 ether/usdt 
        bool success = USDT.transferFrom(msg.sender, address(this), currentPrice); // 6 decimals as USDT uses 6 decimals 
        require(success, "USDT Fee Payment failed, approval or balance error");
        
        //mints nft to user after payment
        _mint(_addr, tokenIds);
        //store tokenId in relation to price
        tokenPrices[tokenIds] = currentPrice;
        //increment token Id
        ++tokenIds;
    }

    //transfer from function to transfer nft from one address to a non eoa
    function transferFrom(address from, address to, uint256 tokenId) public override {
        require(_msgSender() == ownerOf(tokenId), "Caller is not the owner of the token");

        if (msg.sender != owner() && msg.sender != TLPportfolio) {
            uint256 fee = 0;

            if (ownerOf(tokenId) == TLPportfolio) {
                fee = tokenPrices[tokenId] * 5 / 100;
            } else {
                fee = tokenPrices[tokenId] * 10 / 100;
            }

            super.transferFrom(from, XYZburn, tokenId);
            super.transferFrom(from, to, tokenId);

            if (fee > 0) {
                payable(XYZburn).transfer(fee);
            }
        } else {
            super.transferFrom(from, to, tokenId);
        }
    }

    // Withdraws any ETH balance from the contract
    function withdrawETH(address payable recipient) payable external nonReentrant onlyOwner {
        require(recipient != address(0), "Invalid recipient address");
        uint256 balance = address(this).balance;
        recipient.transfer(balance);
    }

    // Withdraws any remaining USDT balance from the contract
    function withdrawUSDT(address recipient) external onlyOwner {
        require(recipient != address(0), "Invalid recipient address");
        USDT.transfer(recipient, USDT.balanceOf(address(this)));
    }

    //Airdrop Wallet
    function airdrop(address[] memory _receivers) external onlyOwner returns (bool) {
        for (uint256 i = 0; i < _receivers.length; ++i) {
            _mint(_receivers[i], tokenIds);
            //increment token Id
            ++tokenIds;
        }
        return true;
    }

    // this is required for transferring/receiving ETH ( either receive or fallback )
    fallback() payable external {}
    receive() payable external {}