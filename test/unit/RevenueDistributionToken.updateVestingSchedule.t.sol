// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {ERC20} from "../../src/ERC20.sol";
import {MockRevertingERC20} from "../mocks/MockRevertingERC20.sol";
import {RevenueDistributionToken} from "src/RevenueDistributionToken.sol";
import {BaseTest} from "../base/BaseTest.sol";
import {PoolTestBase} from "../base/PoolTestBase.sol";
import {PoolSuccessTestBase} from "../base/PoolSuccessTestBase.sol";
import {Staker} from "../accounts/Staker.sol";
// =============================================================
//                       UPDATE VESTING SCHEDULE TESTS
// =============================================================

contract UpdateVestingScheduleFailureTests is PoolTestBase {
    Staker firstStaker;

    uint256 startingAssets;

    function setUp() public virtual override {
        super.setUp();
        firstStaker = new Staker();

        // Deposit the minimum amount of the asset to allow the vesting schedule updates to occur.
        startingAssets = 1;
        asset.mint(address(firstStaker), startingAssets);
        firstStaker.erc20_approve(address(asset), address(pool), startingAssets);
    }

    function test_updateVestingSchedule_zeroSupply() public {
        vm.expectRevert();
        pool.updateVestingSchedule(100 seconds);

        firstStaker.erc20_approve(address(asset), address(pool), 1);
        firstStaker.pool_deposit(address(pool), 1);

        pool.updateVestingSchedule(100 seconds);
    }
}

contract UpdateVestingScheduleTests is PoolTestBase {
    Staker firstStaker;

    uint256 startingAssets;

    function setUp() public virtual override {
        super.setUp();
        firstStaker = new Staker();

        // Deposit the minimum amount of the asset to allow the vesting schedule updates to occur.
        startingAssets = 1;
        asset.mint(address(firstStaker), startingAssets);
        firstStaker.erc20_approve(address(asset), address(pool), startingAssets);
        firstStaker.pool_deposit(address(pool), startingAssets);
    }

    /**
     *
     */
    /**
     * Single updateVestingSchedule **
     */
    /**
     *
     */

    function test_updateVestingSchedule_single() public {
        assertEq(pool.freeAssets(), startingAssets);
        assertEq(pool.totalAssets(), startingAssets);
        assertEq(pool.issuanceRate(), 0);
        assertEq(pool.lastUpdated(), START);
        assertEq(pool.vestingPeriodFinish(), 0);

        assertEq(asset.balanceOf(address(pool)), startingAssets);

        _transferAndUpdateVesting(address(asset), address(pool), 1000, 100 seconds); // 10 tokens per second

        assertEq(asset.balanceOf(address(pool)), startingAssets + 1000);

        assertEq(pool.freeAssets(), startingAssets);
        assertEq(pool.totalAssets(), startingAssets);
        assertEq(pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert);
        assertEq(pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert);
        assertEq(pool.issuanceRate(), 10e30); // 10 tokens per second
        assertEq(pool.lastUpdated(), START);
        assertEq(pool.vestingPeriodFinish(), START + 100 seconds);

        vm.warp(pool.vestingPeriodFinish());

        assertEq(pool.totalAssets(), startingAssets + 1000); // All tokens vested
    }

    function test_updateVestingSchedule_single_roundingDown() public {
        _transferAndUpdateVesting(address(asset), address(pool), 1000, 30 seconds); // 33.3333... tokens per second

        assertEq(pool.totalAssets(), startingAssets);
        assertEq(pool.issuanceRate(), 33333333333333333333333333333333); // 3.33e30

        // totalAssets should never be more than one full unit off
        vm.warp(START + 1 seconds);
        assertEq(pool.totalAssets(), startingAssets + 33); // 33 < 33.33...

        vm.warp(START + 2 seconds);
        assertEq(pool.totalAssets(), startingAssets + 66); // 66 < 66.66...

        vm.warp(START + 3 seconds);
        assertEq(pool.totalAssets(), startingAssets + 99); // 99 < 99.99...

        vm.warp(START + 4 seconds);
        assertEq(pool.totalAssets(), startingAssets + 133); // 133 < 133.33...

        vm.warp(pool.vestingPeriodFinish());
        assertEq(pool.totalAssets(), startingAssets + 999); // 999 < 1000
    }

    /**
     *
     */
    /**
     * Multiple updateVestingSchedule, same time **
     */
    /**
     *
     */

    function test_updateVestingSchedule_sameTime_shorterVesting() public {
        _transferAndUpdateVesting(address(asset), address(pool), 1000, 100 seconds);
        assertEq(pool.issuanceRate(), 10e30); // 1000 / 100 seconds = 10 tokens per second
        assertEq(pool.vestingPeriodFinish(), START + 100 seconds); // Always updates to latest vesting schedule

        _transferAndUpdateVesting(address(asset), address(pool), 1000, 20 seconds);
        assertEq(pool.issuanceRate(), 100e30); // (1000 + 1000) / 20 seconds = 100 tokens per second
        assertEq(pool.vestingPeriodFinish(), START + 20 seconds); // Always updates to latest vesting schedule

        assertEq(pool.totalAssets(), startingAssets);

        vm.warp(START + 20 seconds);

        assertEq(pool.totalAssets(), startingAssets + 2000);
    }

    function test_updateVestingSchedule_sameTime_longerVesting_higherRate() public {
        _transferAndUpdateVesting(address(asset), address(pool), 1000, 100 seconds);
        assertEq(pool.issuanceRate(), 10e30); // 1000 / 100 seconds = 10 tokens per second
        assertEq(pool.vestingPeriodFinish(), START + 100 seconds); // Always updates to latest vesting schedule

        _transferAndUpdateVesting(address(asset), address(pool), 3000, 200 seconds);
        assertEq(pool.issuanceRate(), 20e30); // (3000 + 1000) / 200 seconds = 20 tokens per second
        assertEq(pool.vestingPeriodFinish(), START + 200 seconds); // Always updates to latest vesting schedule

        assertEq(pool.totalAssets(), startingAssets);

        vm.warp(START + 200 seconds);

        assertEq(pool.totalAssets(), startingAssets + 4000);
    }

    function test_updateVestingSchedule_sameTime_longerVesting_lowerRate() public {
        _transferAndUpdateVesting(address(asset), address(pool), 1000, 100 seconds);
        assertEq(pool.issuanceRate(), 10e30); // 1000 / 100 seconds = 10 tokens per second
        assertEq(pool.vestingPeriodFinish(), START + 100 seconds); // Always updates to latest vesting schedule

        _transferAndUpdateVesting(address(asset), address(pool), 1000, 500 seconds);
        assertEq(pool.issuanceRate(), 4e30); // (1000 + 1000) / 500 seconds = 4 tokens per second
        assertEq(pool.vestingPeriodFinish(), START + 500 seconds); // Always updates to latest vesting schedule

        assertEq(pool.totalAssets(), startingAssets);

        vm.warp(START + 5000 seconds);

        assertEq(pool.totalAssets(), startingAssets + 2000);
    }

    /**
     *
     */
    /**
     * Multiple updateVestingSchedule, different times **
     */
    /**
     *
     */

    function test_updateVestingSchedule_diffTime_shorterVesting() public {
        _transferAndUpdateVesting(address(asset), address(pool), 1000, 100 seconds); // 10 tokens per second

        vm.warp(START + 60 seconds);

        assertEq(pool.issuanceRate(), 10e30);
        assertEq(pool.totalAssets(), startingAssets + 600);
        assertEq(pool.freeAssets(), startingAssets);
        assertEq(pool.vestingPeriodFinish(), START + 100 seconds);

        _transferAndUpdateVesting(address(asset), address(pool), 1000, 20 seconds); // 50 tokens per second

        assertEq(pool.issuanceRate(), 70e30); // (400 + 1000) / 20 seconds = 70 tokens per second
        assertEq(pool.totalAssets(), startingAssets + 600);
        assertEq(pool.freeAssets(), startingAssets + 600);
        assertEq(pool.vestingPeriodFinish(), START + 60 seconds + 20 seconds);

        vm.warp(START + 60 seconds + 20 seconds);

        assertEq(pool.issuanceRate(), 70e30);
        assertEq(pool.totalAssets(), startingAssets + 2000);
        assertEq(pool.freeAssets(), startingAssets + 600);
    }

    function test_updateVestingSchedule_diffTime_longerVesting_higherRate() public {
        _transferAndUpdateVesting(address(asset), address(pool), 1000, 100 seconds); // 10 tokens per second

        vm.warp(START + 60 seconds);

        assertEq(pool.issuanceRate(), 10e30);
        assertEq(pool.totalAssets(), startingAssets + 600);
        assertEq(pool.freeAssets(), startingAssets);
        assertEq(pool.vestingPeriodFinish(), START + 100 seconds);

        _transferAndUpdateVesting(address(asset), address(pool), 3000, 200 seconds); // 15 tokens per second

        assertEq(pool.issuanceRate(), 17e30); // (400 + 3000) / 200 seconds = 17 tokens per second
        assertEq(pool.totalAssets(), startingAssets + 600);
        assertEq(pool.freeAssets(), startingAssets + 600);

        vm.warp(START + 60 seconds + 200 seconds);

        assertEq(pool.issuanceRate(), 17e30);
        assertEq(pool.totalAssets(), startingAssets + 4000);
        assertEq(pool.freeAssets(), startingAssets + 600);
    }

    function test_updateVestingSchedule_diffTime_longerVesting_lowerRate() public {
        _transferAndUpdateVesting(address(asset), address(pool), 1000, 100 seconds); // 10 tokens per second

        vm.warp(START + 60 seconds);

        assertEq(pool.issuanceRate(), 10e30);
        assertEq(pool.totalAssets(), startingAssets + 600);
        assertEq(pool.freeAssets(), startingAssets);

        _transferAndUpdateVesting(address(asset), address(pool), 1000, 200 seconds); // 5 tokens per second

        assertEq(pool.issuanceRate(), 7e30); // (400 + 1000) / 200 seconds = 7 tokens per second
        assertEq(pool.totalAssets(), startingAssets + 600);
        assertEq(pool.freeAssets(), startingAssets + 600);

        vm.warp(START + 60 seconds + 200 seconds);

        assertEq(pool.issuanceRate(), 7e30);
        assertEq(pool.totalAssets(), startingAssets + 2000);
        assertEq(pool.freeAssets(), startingAssets + 600);
    }
}
