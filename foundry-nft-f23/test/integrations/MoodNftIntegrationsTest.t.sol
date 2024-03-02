// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MoodNft} from "../../src/MoodNft.sol";
import {DeployMoodNft} from "../../script/DeployMoodNft.s.sol";

import {MoodNftTestHelper} from "../utils/MoodNftTestHelper.sol";

contract MoodNftIntegrationsTest is Test, MoodNftTestHelper {
  MoodNft public moodNft;
  DeployMoodNft public moodNftDeployer;

  address public USER = makeAddr("user");
  address public USER2 = makeAddr("user2");

  function setUp() public {
    moodNftDeployer = new DeployMoodNft();
    moodNft = moodNftDeployer.run();
  }

  function test_viewTokenURI() public {
    vm.prank(USER);
    moodNft.mintNft();
    console.log(moodNft.tokenURI(0));
  }

  function test_canFlipTokenMood() public {
    vm.startPrank(USER);
    moodNft.mintNft();
    moodNft.flipMood(0);
    vm.stopPrank();
    string memory tokenUriExpected = getNftURIFromImage(moodNftDeployer.svgToImageURI(vm.readFile("./images/dynamicNft/sad.svg")) ,moodNft.name());

    MoodNft.Mood tokenMood = moodNft.getTokenMood(0);
    assert(tokenMood == MoodNft.Mood.SAD);
    assertEq(keccak256(abi.encodePacked(moodNft.tokenURI(0))), keccak256(abi.encodePacked(tokenUriExpected)));
  }

  function test_canNotFlipMoodWhenNotOwner() public {
    vm.prank(USER);
    moodNft.mintNft();

    vm.prank(USER2);
    vm.expectRevert();
    moodNft.flipMood(0);
  }
}