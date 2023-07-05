// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../src/XYZ.sol";
import "forge-std/Test.sol";


contract XYZTest is Test {
    XYZContract token;

    function setUp() public {
        token = new XYZContract(
            address(0x08),address(0x09),address(0x10),address(0x11),address(0x12),address(0x13),address(0x14),address(0x15),address(0x16),address(0x17));
            
    }

    //should revert does not have tokens
    function testCreate() public {
        bytes memory trial;
        token.createProposal("create", trial);
        token.createProposal("create", trial);
    }

    function testCreateWithToken() public {

    }
}
