// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Script} from "../lib/forge-std/src/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint ticketPrice;
        uint interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint subscriptionId;
        uint32 callbackGasLimit;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaETHConfig();
        } else if (block.chainit == 1) {
            // mainnet
        } else {
            activeNetworkConfig = getOrCreateAnvilETHConfig();
        }
    }

    function getSepoliaETHConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                ticketPrice: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0, // TODO update this with our subscriptionId !!
                callbackGasLimit: 500000 // 500 000 gas
            });
    }

    function getOrCreateAnvilETHConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        // return NetworkConfig({})
    }
}
