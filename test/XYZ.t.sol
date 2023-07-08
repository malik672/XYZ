// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../src/XYZ.sol";
import "forge-std/Test.sol";
import "../src/TLP.sol";

contract XYZTest is Test {
    address[] addr = [msg.sender, address(0x15)];
    XYZContract token;
    TheLoungePass tlp;

    function setUp() public {
        vm.startPrank(msg.sender);
        tlp = new TheLoungePass(msg.sender, address(0x15), address(0x15));
        token = new XYZContract(
            address(0x08),address(0x09),address(0x10),address(0x11),address(0x12),address(0x13),msg.sender,address(0x15),address(0x03), address(0x03), address(0x16),address(tlp));

        vm.stopPrank();
    }

    //should revert does not have tokens
    function testCreate() public {
        bytes memory trial;
        token.createProposal("create");
        token.createProposal("create");
    }

    //should be successful
    function testCreateWithToken() public {
        bytes memory trial = bytes("did it work");
        vm.startPrank(msg.sender);
        tlp.airdrop(addr);
        token.checkBalanceAndAssignRole(msg.sender);
        token.createProposal("create");
        vm.stopPrank();
    }

    //should be successful
    function testCreateWithTokes() public {
        bytes memory trial = bytes("did it work");
        vm.startPrank(msg.sender);
        tlp.airdrop(addr);
        token.checkBalanceAndAssignRole(msg.sender);
        token.createProposal("create");
        vm.stopPrank();
    }

    //should be successful
    function testvoteonProposal() public {
        bytes memory trial = bytes("did it work");
        vm.startPrank(msg.sender);
        tlp.airdrop(addr);
        token.checkBalanceAndAssignRole(msg.sender);
        token.createProposal("create");
        token.voteOnProposal(1, true);
        vm.stopPrank();
    }

    //should be successful// use non existing proposalID
    function testwrongvoteonProposal() public {
        bytes memory trial = bytes("did it work");
        vm.startPrank(msg.sender);
        tlp.airdrop(addr);
        token.checkBalanceAndAssignRole(msg.sender);
        token.createProposal("create");
        token.voteOnProposal(2, true);
        vm.stopPrank();
    }

    //should not be successful// use non existing proposalID
    function testfinalized() public {
        bytes memory trial = bytes("did it work");
        vm.startPrank(msg.sender);
        tlp.airdrop(addr);
        token.checkBalanceAndAssignRole(msg.sender);
        token.createProposal("create");
        token.voteOnProposal(1, true);
        vm.warp(block.timestamp);
        token.finalizeProposal(1);
        vm.stopPrank();
    }
    //should not be successful// use non existing proposalID

    function testfinalizeds() public {
        bytes memory trial = bytes("did it work");
        vm.startPrank(msg.sender);
        tlp.airdrop(addr);
        token.checkBalanceAndAssignRole(msg.sender);
        token.createProposal("create");
        token.voteOnProposal(1, true);
        vm.warp(block.timestamp + 3 days);
        token.finalizeProposal(2);
        vm.stopPrank();
    }

    //should be successful// use non existing proposalID
    function testfinalize() public {
        bytes memory trial = bytes("did it work");
        vm.startPrank(msg.sender);
        tlp.airdrop(addr);
        token.checkBalanceAndAssignRole(msg.sender);
        token.createProposal("create");
        token.voteOnProposal(1, true);
        vm.warp(block.timestamp + 12 days);
        token.finalizeProposal(1);
        vm.stopPrank();
    }
}
