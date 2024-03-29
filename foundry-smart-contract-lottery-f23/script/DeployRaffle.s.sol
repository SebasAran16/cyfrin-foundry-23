// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {RaffleHelperConfig} from "./RaffleHelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./RaffleInteractions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle raffleAddress, RaffleHelperConfig raffleHelperConfig) {
        raffleHelperConfig = new RaffleHelperConfig();

        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address linkAddress,
            uint256 deployerKey
        ) = raffleHelperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployerKey);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, linkAddress, deployerKey);
        }

        vm.startBroadcast();
        raffleAddress = new Raffle(entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit);
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffleAddress), vrfCoordinator, subscriptionId, deployerKey);
    }
}
