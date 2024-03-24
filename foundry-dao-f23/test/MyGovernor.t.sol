// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {GovToken} from "../src/GovToken.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGovernorTest is Test {
  MyGovernor public governor;
  GovToken public govToken;
  Box public box;
  TimeLock public timeLock;

  address public USER = makeAddr("user");
  uint256 public constant INITIAL_SUPPLY = 100 ether;
  uint256 public constant MIN_DELAY = 3600; // 1 hour - after vote passes
  uint256 public constant VOTING_DELAY = 7200; // how many block till a vote is active
  uint256 public constant VOTING_PERIOD = 50400 + 7200; // how many block till a vote is active
  bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

  address[] public proposers;
  address[] public executors;

  function setUp() public {
    govToken = new GovToken();
    govToken.mint(USER,INITIAL_SUPPLY);

    vm.startPrank(USER);
    govToken.delegate(USER);
    timeLock = new TimeLock(1 days, proposers, executors);
    governor = new MyGovernor(govToken, timeLock);

    bytes32 proposerRole = timeLock.PROPOSER_ROLE();
    bytes32 executorRole = timeLock.EXECUTOR_ROLE();

    timeLock.grantRole(proposerRole, address(governor));
    timeLock.grantRole(executorRole, address(0)); // Anybody can
    timeLock.revokeRole(DEFAULT_ADMIN_ROLE, USER);
    vm.stopPrank();

    box = new Box();
    box.transferOwnership(address(timeLock));
  }

  function test_canUpdateBoxWithoutGovernance() public {
    vm.expectRevert();
    box.store(1);
  }

  function test_governanceUpdateBox() public {
    uint256 valueToStore = 888;

    address[] memory targets = new address[](1);
    targets[0] = address(box);

    uint256[] memory values = new uint256[](1);
    values[0] = 0;

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSignature("store(uint256)", valueToStore);

    string memory description = "Store 1 in Box";

    // 1. Propose
    uint proposalId = governor.propose(targets, values, calldatas, description);

    console.log("Proposal State:", vm.toString(uint256(governor.state(proposalId))));

    vm.warp(block.timestamp + VOTING_DELAY + 1);
    vm.roll(block.number + VOTING_DELAY + 1);

    console.log("Proposal State:", vm.toString(uint256(governor.state(proposalId))));

    // 2. Vote
    string memory reason = "Cuz blue frog is cool";
    uint8 voteWay = 1; // Voting yes
    vm.prank(USER);
    governor.castVoteWithReason(proposalId, voteWay, reason);

    vm.warp(block.timestamp + VOTING_PERIOD + 1);
    vm.roll(block.number + VOTING_PERIOD + 1);

    // 3. Queue the TX
    bytes32 descriptionHash = keccak256(abi.encodePacked(description));
    governor.queue(targets, values, calldatas, descriptionHash);
    vm.warp(block.timestamp + MIN_DELAY * 25 + 1);
    vm.roll(block.number + MIN_DELAY * 25 + 1);

    bool isOperationReady = timeLock.isOperationReady(keccak256(abi.encodePacked(proposalId)));

    // 4. Execute
    governor.execute(targets, values, calldatas, descriptionHash);

    assert(box.getNumber() == valueToStore);
  }
}