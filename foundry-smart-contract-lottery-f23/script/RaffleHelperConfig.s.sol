// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract RaffleHelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address linkAddress;
        uint256 deployerKey;
    }

    uint256 constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaETHConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilETHConfig();
        }
    }

    function getSepoliaETHConfig() public view returns (NetworkConfig memory sepoliaConfig) {
        sepoliaConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef,
            subscriptionId: 8784,
            callbackGasLimit: 500000, // 500,000 gas
            linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: vm.envUint("METAMASK_TEST1_PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilETHConfig() public returns (NetworkConfig memory anvilConfig) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) return activeNetworkConfig;

        uint96 baseFee = 0.25 ether;
        uint96 gasPriveLink = 1e9;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(baseFee, gasPriveLink);
        vm.stopBroadcast();

        LinkToken linkToken = new LinkToken();

        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef,
            subscriptionId: 0,
            callbackGasLimit: 500000, // 500,000 gas
            linkAddress: address(linkToken),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
}
