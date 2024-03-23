// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private s_number;

    event NumberChanged(uint256 indexed newNumber);

    constructor() Ownable(msg.sender) {}

    function store(uint256 newNumber) external onlyOwner {
        s_number = newNumber;

        emit NumberChanged(newNumber);
    }

    function getNumber() public view returns (uint256) {
        return s_number;
    }
}
