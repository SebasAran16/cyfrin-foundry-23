// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";

contract OurTokenTest is Test {
  OurToken public ourToken;
  DeployOurToken public deployer;

  address public bob = makeAddr("Bob");
  address public alice = makeAddr("Alice");

  uint256 public constant STARTING_BALANCE = 100 ether;

  function setUp() public {
    deployer = new DeployOurToken();
    ourToken = deployer.run();

    vm.prank(msg.sender);
    ourToken.transfer(bob, STARTING_BALANCE);
  }

  function test_bobBalance() public {
    assertEq(STARTING_BALANCE, ourToken.balanceOf(bob));
  }

  function test_allowances() public {
    uint256 initialAllowance = 1000;

    vm.prank(bob);
    ourToken.approve(alice, initialAllowance);

    uint256 transferAmount = 500;

    vm.prank(alice);
    ourToken.transferFrom(bob, alice, transferAmount);

    assertEq(ourToken.balanceOf(alice), transferAmount);
    assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
  }

  function test_transfers() public {
    uint256 transferAmount = 200;
    vm.prank(bob);
    ourToken.transfer(alice, transferAmount);

    assertEq(ourToken.balanceOf(alice), transferAmount, "Alice balance is incorrect after transfer");
    assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount, "Bob balance is incorrect after transfer");
  }

  function test_insufficientAllowance() public {
    uint256 initialAllowance = 100;

    vm.prank(bob);
    ourToken.approve(alice, initialAllowance);

    uint256 transferAmount = 200;

    vm.prank(alice);
    vm.expectRevert();
    ourToken.transferFrom(bob, alice, transferAmount);

    assertEq(ourToken.balanceOf(alice), 0, "Alice balance should not change");
    assertEq(ourToken.balanceOf(bob), STARTING_BALANCE, "Bob balance should not change");
    assertEq(ourToken.allowance(bob, alice), initialAllowance, "Allowance should not change");
  }

  function test_approveAndTransfer() public {
    uint256 approvalAmount = 500;
    vm.prank(bob);
    ourToken.approve(alice, approvalAmount);

    uint256 transferAmount = 300;
    vm.prank(alice);
    ourToken.transferFrom(bob, alice, transferAmount);

    assertEq(ourToken.balanceOf(alice), transferAmount, "Alice balance is incorrect after transfer");
    assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount, "Bob balance is incorrect after transfer");
    assertEq(ourToken.allowance(bob, alice), approvalAmount - transferAmount, "Allowance after transferFrom is incorrect");
  }
}