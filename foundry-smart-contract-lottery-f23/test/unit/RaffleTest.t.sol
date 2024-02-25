// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {RaffleHelperConfig} from "../../script/RaffleHelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffleContract;
    RaffleHelperConfig raffleHelperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkAddress;
    uint256 deployerKey;

    modifier upkeepConditions() {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();

        skip(interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle raffleDeployer = new DeployRaffle();
        (raffleContract, raffleHelperConfig) = raffleDeployer.run();

        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, linkAddress,) =
            raffleHelperConfig.activeNetworkConfig();
        (,,,,,,,deployerKey) = raffleHelperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    ////////////////////
    //  Constructor  //
    //////////////////

    function test_constructor_initializesInOpenState() public view {
        assert(raffleContract.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ////////////////////
    //  enterRaffle  //
    //////////////////

    function test_enterRaffle_revertsWhenNotPayingEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffleContract.enterRaffle();
    }

    function test_enterRaffle_recordsPlayerWhenEntering() public {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
        address playerRecorded = raffleContract.getPlayer(0);

        assertEq(playerRecorded, PLAYER);
    }

    function test_enterRaffle_emitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffleContract));
        emit Raffle.EnterRaffle(PLAYER);

        raffleContract.enterRaffle{value: entranceFee}();
    }

    function test_enterRaffle_canNotEnterWhenRaffleIsNotOpen() public upkeepConditions {
        raffleContract.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();
    }

    ////////////////////
    //  checkUpkeep  //
    //////////////////

    function test_checkUpkeep_returnsFalseIfHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffleContract.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function test_checkUpkeep_returnsFalseIfRaffleIsNotOpen() public upkeepConditions {
        raffleContract.performUpkeep("");

        (bool upkeepNeeded,) = raffleContract.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function test_checkUpkeep_returnsFalseIfHasNotPassedInterval() public {
        vm.prank(PLAYER);
        raffleContract.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded,) = raffleContract.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function test_checkUpkeep_returnsTrueWhenConditionsAreFine() public upkeepConditions {
        (bool upkeepNeeded,) = raffleContract.checkUpkeep("");
        assert(upkeepNeeded);
    }

    //////////////////////
    //  performUpkeep  //
    ////////////////////

    function test_performUpkeep_canOnlyRunIfCheckUpkeepIsTrue() public upkeepConditions {
        raffleContract.performUpkeep("");
    }

    function test_performUpkeep_revertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 playersLength = 0;
        uint256 raffleState = uint256(Raffle.RaffleState.OPEN);

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, playersLength, raffleState)
        );
        raffleContract.performUpkeep("");
    }

    function test_performUpkeep_updatesRaffleStateAndEmitRequestId() public upkeepConditions {
        vm.recordLogs();
        raffleContract.performUpkeep("");

        Vm.Log[] memory logEntries = vm.getRecordedLogs();
        bytes32 requestId = logEntries[1].topics[1];

        Raffle.RaffleState raffleState = raffleContract.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    ///////////////////////////
    //  fulfillRandomWords  //
    /////////////////////////

    function test_fulfillRandomWords_canOnlyBeCalledAfterPerformedUpkeep(uint256 randomSubscriptionId) public skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomSubscriptionId, address(raffleContract));
    }

    function test_fulfillRandomWords_picksAWinnerResetsAndSendsMoney() public upkeepConditions skipFork {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);

            raffleContract.enterRaffle{value: entranceFee}();
        }

        vm.recordLogs();
        raffleContract.performUpkeep("");
        Vm.Log[] memory logsEntries = vm.getRecordedLogs();
        bytes32 gotSubscriptionId = logsEntries[1].topics[1];

        uint256 previousTimestamp = raffleContract.getLatestTimestamp();

        // Pretend to be Chainlink VRF Coordinator to get random number & get a winner
        vm.recordLogs();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(gotSubscriptionId), address(raffleContract));
        logsEntries = vm.getRecordedLogs();

        bytes32 raffleWinner = logsEntries[0].topics[1];
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(raffleContract.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffleContract.getRecentWinner() != address(0));
        assert(raffleContract.getPlayersLength() == 0);
        assert(raffleContract.getLatestTimestamp() > previousTimestamp);
        assert(uint256(raffleWinner) > 0 && uint256(raffleWinner) < additionalEntrants + 1);
        assert(raffleContract.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);
    }
}
