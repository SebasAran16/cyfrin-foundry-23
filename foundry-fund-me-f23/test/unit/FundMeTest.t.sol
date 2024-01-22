// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { FundMe } from "../../src/FundMe.sol";
import { DeployFundMe } from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMeContract;
    
    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    modifier funded() {
        vm.prank(USER);
        fundMeContract.fund{value: SEND_VALUE}();
        _;
    }

    function setUp() external {
        DeployFundMe deployFundMeContract = new DeployFundMe();
    
        fundMeContract = deployFundMeContract.run();
        deal(USER, STARTING_BALANCE);
    }

    function test_MinumumDollarIsFive() public {
        assertEq(fundMeContract.MINIMUM_USD(), 5e18);
    }

    function test_ownerIsMsgSender() public {
        assertEq(fundMeContract.getOwner(), msg.sender);
    }

    function test_priceFeedVersionIsAccurate() public {
        uint256 version = fundMeContract.getVersion();
        assertEq(version, 4);
    }

    function test_fund_checkFailsWithoutEnoughETH() public {
        vm.expectRevert(); // Next line MUST revert
        fundMeContract.fund();
    }

    function test_fund_updatesFundedDataStructure() public funded {
        uint256 walletAmountFunded = fundMeContract.getAddressToAmountFunded(USER);

        assertEq(walletAmountFunded, SEND_VALUE);
    }

    function test_fund_addsFunderToFundersArray() public funded {
        address funder = fundMeContract.getFunder(0);

        assertEq(funder, USER);
    }

    function test_withdraw_onlyOwnerCanWithdraw() public funded {
        vm.expectRevert();
        vm.prank(USER);
        fundMeContract.withdraw();
    }

    function test_withdraw_withdrawWithSingleFunder() public funded {
        // Arrange
        uint256 startingOwnerBalance = fundMeContract.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMeContract).balance;

        // Act
        vm.prank(fundMeContract.getOwner());
        fundMeContract.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMeContract.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMeContract).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(endingOwnerBalance, startingFundMeBalance + startingOwnerBalance);
    }

    function test_withdraw_withdrawWithMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank() && vm.deal() replacer
            hoax(address(i), SEND_VALUE);
            fundMeContract.fund{value: SEND_VALUE}();
        }
        
        // Arrange
        uint256 startingOwnerBalance = fundMeContract.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMeContract).balance;

        // Act
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMeContract.getOwner());
        fundMeContract.withdraw();
        vm.stopPrank();

        // Assert
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log(gasUsed);

        uint256 endingOwnerBalance = fundMeContract.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMeContract).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(endingOwnerBalance, startingFundMeBalance + startingOwnerBalance);
    }

    function test_cheaperWithdraw_withdrawWithMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank() && vm.deal() replacer
            hoax(address(i), SEND_VALUE);
            fundMeContract.fund{value: SEND_VALUE}();
        }
        
        // Arrange
        uint256 startingOwnerBalance = fundMeContract.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMeContract).balance;

        // Act
        uint256 gasStart = gasleft();
        vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMeContract.getOwner());
        fundMeContract.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        uint256 gasEnd = gasleft();
        uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        console.log(gasUsed);

        uint256 endingOwnerBalance = fundMeContract.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMeContract).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(endingOwnerBalance, startingFundMeBalance + startingOwnerBalance);
    }
}