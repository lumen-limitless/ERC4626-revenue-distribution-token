// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {RevenueDistributionToken} from "src/RevenueDistributionToken.sol";
import {BaseTest} from "../base/BaseTest.sol";

contract Warper is BaseTest {
    address internal _pool;

    constructor(address pool_) {
        _pool = pool_;
    }

    function warp(uint256 warpTime_) external {
        vm.warp(block.timestamp + constrictToRange(warpTime_, 1, 100 days));
    }

    function warpAfterVesting(uint256 warpTime_) external {
        vm.warp(
            block.timestamp + RevenueDistributionToken(_pool).vestingPeriodFinish()
                + constrictToRange(warpTime_, 1, 100 days)
        );
    }
}
