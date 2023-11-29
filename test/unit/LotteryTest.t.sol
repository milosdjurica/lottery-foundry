// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {Vm} from "../../lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract LotteryTest is Test {
    // * Events
    // cant import them from lottery, so have to recreate same here
    event EnteredLottery(address indexed player);

    Lottery lottery;
    HelperConfig helperConfig;

    uint ticketPrice;
    uint interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint public constant STARTING_USER_BALANCE = 100 ether;

    modifier lotteryEnteredAndTimePassed() {
        vm.prank(PLAYER);
        lottery.enterLottery{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function setUp() external {
        DeployLottery deployLottery = new DeployLottery();
        (lottery, helperConfig) = deployLottery.run();
        (
            ticketPrice,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testLotteryInitializesInOpenState() public view {
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }

    /////////////////////
    // !enterLottery() //
    /////////////////////
    function testLotteryRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        // Assert
        vm.expectRevert(Lottery.Lottery__NotEnoughETHSent.selector);
        lottery.enterLottery();
    }

    // test for not open state
    function testCantEnterWhenLotteryIsNotOpen() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: ticketPrice}();

        // ! making sure that enough time is passed for lottery to pick winner and sets state to CALCULATING
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        lottery.performUpkeep("");

        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        vm.prank(PLAYER);
        lottery.enterLottery{value: ticketPrice}();
    }

    function testLotteryRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: ticketPrice}();
        address playerRecorded = lottery.getPLayer(0);

        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        // can have only 3 indexed, first is true, other 2 arent,
        // last false is to say that there arent any unindexed parameters
        vm.expectEmit(true, false, false, false, address(lottery));

        // expectEmit() says, i expect next line to emit same event like the line after
        // emit EnteredLottery(PLAYER) should be emited in next function call lottery.enterLottery()
        emit EnteredLottery(PLAYER);
        lottery.enterLottery{value: ticketPrice}();
    }

    ////////////////////
    // !checkUpkeep() //
    ////////////////////
    function checkUpkeepFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function checkUpkeepReturnsFalseIfLotteryNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        lottery.enterLottery{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    //////////////////////
    // !performUpkeep() //
    //////////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: ticketPrice}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint balance = 0;
        uint numPlayers = 0;
        uint lotteryState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__UpkeepNotNeeded.selector,
                balance,
                numPlayers,
                lotteryState
            )
        );
        lottery.performUpkeep("");
    }

    function testPerformUpkeepUpdatesLotteryStateAndEmitsRequestId()
        public
        lotteryEnteredAndTimePassed
    {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Lottery.LotteryState lotteryState = lottery.getLotteryState();

        assert(uint(requestId) > 0);
        assert(uint(lotteryState) == 1);
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint randomRequestId
    ) public lotteryEnteredAndTimePassed {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSetsMoney()
        public
        lotteryEnteredAndTimePassed
    {
        uint additionalEnterance = 5;
        // because 1 is already in (modifier)
        uint startingIndex = 1;
        for (
            uint i = startingIndex;
            i < startingIndex + additionalEnterance;
            i++
        ) {
            address player = address(uint160(i)); // example: address(3)
            hoax(player, STARTING_USER_BALANCE);
            lottery.enterLottery{value: ticketPrice}();
        }

        uint prize = ticketPrice * (additionalEnterance + 1);

        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint previousTimestamp = lottery.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint(requestId),
            address(lottery)
        );

        // assert(uint(lottery.getLotteryState()) == 0);
        // assert(lottery.getRecentWinner() != address(0));
        // assert(lottery.getPlayersLength() == 0);
        // assert(previousTimestamp < lottery.getLastTimeStamp());
        assert(
            lottery.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - ticketPrice
        );
    }
}
