// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title A Simple Lottery Contract
 * @author Milos Djurica
 * @notice This contract gives user a chance to join the lottery and win total prize
 * @dev Implements Chainlink VRFv2
 */
contract Lottery {
    uint private immutable i_ticketPrice;

    constructor(uint ticketPrice) {
        i_ticketPrice = ticketPrice;
    }

    function enterLottery() public payable {}

    function pickWinner() public {}
}
