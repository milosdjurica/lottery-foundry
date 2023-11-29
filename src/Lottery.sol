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
    error Lottery__UpkeepNotNeeded(
        uint currentBalance,
        uint numPlayers,
        uint raffleState
    );
    error Lottery__TransferFailed();
    error Lottery__LotteryNotOpen();

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
    event RequestedLotteryWinner(uint indexed requestId);

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
        // require(msg.value >= i_ticketPrice, "Not enough ETH sent!");
        if (msg.value < i_ticketPrice) revert Lottery__NotEnoughETHSent();
        if (s_lotteryState != LotteryState.OPEN)
            revert Lottery__LotteryNotOpen();

        s_players.push(payable(msg.sender));
        emit EnteredLottery(msg.sender);
    }

    // When the winner is going to be picked?
    /**
     * @dev This is the function that the Chainlink Automation nodes call
     * to see if it is time to perform an upkeep.
     * The following should be true for this to return true:
     * 1. The time interval has passed between Lottery runs
     * 2. The lottery is in the OPEN state
     * 3. The contract has ETH(aka, players)
     * 4. (Implicitl) The subscription is funded with LINK
     */
    function checkUpkeep(
        bytes memory /*checkData*/
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = s_lotteryState == LotteryState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /*performData*/) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded)
            revert Lottery__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint(s_lotteryState)
            );
        s_lotteryState = LotteryState.CALCULATING;
        uint requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // id
            REQUEST_CONFIRMATIONS, // how many blocks should pass
            i_callbackGasLimit, // gass limit
            NUM_WORDS // number of random numbers we get back
        );
        emit RequestedLotteryWinner(requestId);
    }

    // * CEI: Checks, Effects, Interactions -> important design pattern
    // ! better to do checks at start because it is more gas efficient to revert on start
    function fulfillRandomWords(
        uint /*requestId*/,
        uint[] memory randomWords
    ) internal override {
        // Checks -> check for reverts
        // Effects -> effects on our OWN contract
        uint indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        // Interaction -> interacting with other contracts
        // ! delete s_players is more gas efficient ????????????????????????????????????????????
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        (bool success, ) = winner.call{value: address(this).balance}("");

        // ! I leave this Effect after Interaction because if I OPEN state,
        // ! then potentially user can add funds to the contract before the money is transfered
        // ! it could lead
        s_lotteryState = LotteryState.OPEN;

        if (!success) revert Lottery__TransferFailed();
    }

    // * Getters
    function getTicketPrice() external view returns (uint) {
        return i_ticketPrice;
    }

    function getLotteryState() external view returns (LotteryState) {
        return s_lotteryState;
    }

    function getPLayer(uint index) external view returns (address) {
        return s_players[index];
    }
}
