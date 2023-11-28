// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title A Simple Lottery Contract
 * @author Milos Djurica
 * @notice This contract gives user a chance to join the lottery and win total prize
 * @dev Implements Chainlink VRFv2
 */
contract Lottery {
    error Lottery__NotEnoughETHSent();

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint private immutable i_ticketPrice;
    // Duration of the lottery in seconds
    uint private immutable i_interval;
    // ! VRF arguments
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint private s_lastTimeStamp;
    address payable[] private s_players; // payable because we have to pay the winner at the end

    // Events
    event EnteredLottery(address indexed player);

    constructor(
        uint ticketPrice,
        uint interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) {
        i_ticketPrice = ticketPrice;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
    }

    function enterLottery() external payable {
        // ! Old way, but custom errors are more gas efficient
        // ! If the condition is TRUE, then dont rever, if false revert with "Not enough ETH sent!"
        // require(msg.value >= i_ticketPrice, "Not enough ETH sent!");
        if (msg.value < i_ticketPrice) revert Lottery__NotEnoughETHSent();
        s_players.push(payable(msg.sender));

        emit EnteredLottery(msg.sender);
    }

    // Get random number
    // Use rand num to pick a player
    // Be automatically called
    function pickWinner() external {
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert();
        }

        uint requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // id
            REQUEST_CONFIRMATIONS, // how many blocks should pass
            i_callbackGasLimit, // gass limit
            NUM_WORDS // number of random numbers we get back
        );
        // 1. Request RNG
        // 2. Get random number
    }

    // ! Getters
    function getTicketPrice() external view returns (uint) {
        return i_ticketPrice;
    }
}
