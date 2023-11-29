// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script, console} from "../lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

import {HelperConfig} from "./HelperConfig.s.sol";

contract CreateSubscription is Script {
    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , uint64 vrfCoordinator, , , ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint64) {
        console.log("Creating subscrpition on ChainId ", block.chainid);

        vm.startBroadcast();

        uin64 subscriptionid = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is: ", subscriptionId);
        console.log("Update subId in HelperConfig.s.sol")
        return subscriptionId;
    }
}
