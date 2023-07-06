// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Lock is TokenTimelock {
   

    constructor(address _token, uint256 _time) TokenTimelock(IERC20(_token), msg.sender, _time) payable {
        IERC20 token;
        token = IERC20(_token);
   
    }
}
