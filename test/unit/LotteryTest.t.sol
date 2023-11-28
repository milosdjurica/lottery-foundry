// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery lottery;

    address public constant PLAYER = makeAddr("player");
    uint public constant STARTING_USER_BALANCE = 100 ether;

    function setUp() external {
        DeployLottery deployLottery = new DeployLottery();
        lottery = deployLottery.run();
    }
}
