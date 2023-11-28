// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A Simple Lottery Contract
 * @author Milos Djurica
 * @notice This contract gives user a chance to join the lottery and win total prize
 * @dev Implements Chainlink VRFv2
 */
contract Lottery is VRFConsumerBaseV2 {
    error Lottery__NotEnoughETHSent();
    error Lottery__NotEnoughTimePassed();
    error Lottery__TransferFailed();
    error Lottery__CalculatingWinner();

    // * Type Declarations
    // using enum because we could have multiple states -> open, closed, calculating, etc...

    enum LotteryState {
        OPEN, // 0
        CALCULATING // 1
    }

    // * State Variables
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
    address private s_recentWinner;
    address payable[] private s_players; // payable because we have to pay the winner at the end

    LotteryState private s_lotteryState;

    // * Events
    event EnteredLottery(address indexed player);
    event PickedWinner(address indexed winner);

    constructor(
        uint ticketPrice,
        uint interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_ticketPrice = ticketPrice;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;

        s_lastTimeStamp = block.timestamp;
    }

    function enterLottery() external payable {
        // ! Old way, but custom errors are more gas efficient
        // ! If the condition is TRUE, then dont rever, if false revert with "Not enough ETH sent!"
        // require(msg.value >= i_ticketPrice, "Not enough ETH sent!");
        if (msg.value < i_ticketPrice) revert Lottery__NotEnoughETHSent();
        if (s_lotteryState != LotteryState.OPEN)
            revert Lottery__CalculatingWinner();

        s_players.push(payable(msg.sender));
        emit EnteredLottery(msg.sender);
    }

    function pickWinner() external {
        if (block.timestamp - s_lastTimeStamp < i_interval)
            revert Lottery__NotEnoughTimePassed();

        s_lotteryState = LotteryState.CALCULATING;
        uint requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // id
            REQUEST_CONFIRMATIONS, // how many blocks should pass
            i_callbackGasLimit, // gass limit
            NUM_WORDS // number of random numbers we get back
        );
    }

    // CEI: Checks, Effects, Interactions -> important design pattern
    function fulfillRandomWords(
        uint requestId,
        uint[] memory randomWords
    ) internal override {
        uint indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        (bool success, ) = winner.call{value: address(this).balance}("");

        s_players = new address payable[](0);
        s_lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;

        if (!success) revert Lottery__TransferFailed();
        emit PickedWinner(winner);
    }

    // * Getters
    function getTicketPrice() external view returns (uint) {
        return i_ticketPrice;
    }
}
