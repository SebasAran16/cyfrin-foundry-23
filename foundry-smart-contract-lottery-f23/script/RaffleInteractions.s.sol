// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {RaffleHelperConfig} from "./RaffleHelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64 subscriptionId) {
        RaffleHelperConfig raffleHelper = new RaffleHelperConfig();

        (,, address vrfCoordinator,,,,, uint256 deployerKey) = raffleHelper.activeNetworkConfig();
        subscriptionId = createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint64 subscriptionId) {
        console.log("Creating Chainlink VRF Subscription on Chain ID: ", block.chainid);

        vm.startBroadcast(deployerKey);
        subscriptionId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription ID is :", subscriptionId);
    }

    function run() external returns (uint64 subscriptionId) {
        subscriptionId = createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        RaffleHelperConfig raffleHelper = new RaffleHelperConfig();

        (,, address vrfCoordinator,, uint64 subscriptionId,, address linkAddress, uint256 deployerKey) = raffleHelper.activeNetworkConfig();

        fundSubscription(vrfCoordinator, subscriptionId, linkAddress, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint64 subscriptionId, address linkAddress, uint256 deployerKey) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using VRF Coordinator: ", vrfCoordinator);
        console.log("On Chain Id: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(linkAddress).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffleAddress) public {
        RaffleHelperConfig raffleHelper = new RaffleHelperConfig();

        (,, address vrfCoordinator,, uint64 subscriptionId,,, uint256 deployerKey) = raffleHelper.activeNetworkConfig();

        addConsumer(raffleAddress, vrfCoordinator, subscriptionId, deployerKey);
    }

    function addConsumer(address raffleAddress, address vrfCoordinator, uint64 subscriptionId, uint256 deployerKey)
        public
    {
        console.log("Adding consumer Contract: ", raffleAddress);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On Chain ID: ", block.chainid);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId, raffleAddress);
        vm.stopBroadcast();
    }

    function run() external {
        address raffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);

        addConsumerUsingConfig(raffleAddress);
    }
}
