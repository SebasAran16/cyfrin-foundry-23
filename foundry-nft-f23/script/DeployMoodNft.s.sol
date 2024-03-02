// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MoodNft} from "../src/MoodNft.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployMoodNft is Script {
    function run() external returns (MoodNft moodNft) {
        string memory sadSvg = vm.readFile("./images/dynamicNft/sad.svg");
        string memory happySvg = vm.readFile("./images/dynamicNft/happy.svg");

        vm.startBroadcast();
        moodNft = new MoodNft(svgToImageURI(sadSvg), svgToImageURI(happySvg));
        vm.stopBroadcast();
    }

    function svgToImageURI(string memory svg) public pure returns (string memory imageURI) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory base64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));

        imageURI = string(abi.encodePacked(baseURL, base64Encoded));
    }
}
