// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.20;

import {RevenueDistributionToken} from "src/RevenueDistributionToken.sol";

import "forge-std/Script.sol";

contract RevenueDistributionTokenScript is Script {
    function run() external returns (RevenueDistributionToken deployment) {
        vm.startBroadcast();

        deployment =
        new RevenueDistributionToken("test", "test", address(1), address(0x476908D9f75687684CE3DBF6990e722129cDbCc6), 1e30);

        vm.stopBroadcast();
    }
}
