// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title A Simple Lottery Contract
 * @author Milos Djurica
 * @notice This contract gives user a chance to join the lottery and win total prize
 * @dev Implements Chainlink VRFv2
 */
contract Lottery {
    error Lottery__NotEnoughETHSent();

    uint private immutable i_ticketPrice;
    address payable[] private s_players; // payable because we have to pay the winner at the end

    // Events
    event EnteredLottery(address indexed player);

    constructor(uint ticketPrice) {
        i_ticketPrice = ticketPrice;
    }

    function enterLottery() external payable {
        // ! Old way, but custom errors are more gas efficient
        // ! If the condition is TRUE, then dont rever, if false revert with "Not enough ETH sent!"
        // require(msg.value >= i_ticketPrice, "Not enough ETH sent!");
        if (msg.value < i_ticketPrice) revert Lottery__NotEnoughETHSent();
        s_players.push(payable(msg.sender));

        emit EnteredLottery(msg.sender);
    }

    function pickWinner() public {}

    // ! Getters
    function getTicketPrice() external view returns (uint) {
        return i_ticketPrice;
    }
}
