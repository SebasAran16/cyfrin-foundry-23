// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { FundMe } from "../../src/FundMe.sol";
import { DeployFundMe } from "../../script/DeployFundMe.s.sol";
import { FundFundMe, WithdrawFundMe } from "../../script/Interactions.s.sol";

contract FundMeInteractionsTest is Test {
    FundMe fundMeContract;

    address USER = makeAddr("user");
    uint256 STARTING_BALANCE = 10 ether;
    uint256 GAS_PRICE = 1;
    uint256 SEND_VALUE = 0.01 ether;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMeContract = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function test_fundIntegration_userCanFund() public {
        FundFundMe fundFundMe = new FundFundMe();
        fundFundMe.fundFundMe(address(fundMeContract));

        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMeContract));

        assert(address(fundMeContract).balance == 0);
    }
}