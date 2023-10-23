// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.7;

import {PoolTestBase} from "../base/PoolTestBase.sol";
import {Staker} from "../accounts/Staker.sol";

// =============================================================
//                       E2E VESTING TESTS
// =============================================================

contract EndToEndTests is PoolTestBase {
    function test_vesting_singleSchedule_explicitValues() public {
        uint256 depositAmount = 1_000_000e18;
        uint256 vestingAmount = 100_000e18;
        uint256 vestingPeriod = 200_000 seconds;

        Staker staker = new Staker();

        asset.mint(address(staker), depositAmount);

        staker.erc20_approve(address(asset), address(pool), depositAmount);
        staker.pool_deposit(address(pool), depositAmount);

        assertEq(pool.freeAssets(), 1_000_000e18);
        assertEq(pool.totalAssets(), 1_000_000e18);
        assertEq(pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert);
        assertEq(pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert);
        assertEq(pool.issuanceRate(), 0);
        assertEq(pool.lastUpdated(), START);
        assertEq(pool.vestingPeriodFinish(), 0);

        vm.warp(START + 1 days);

        assertEq(pool.totalAssets(), 1_000_000e18); // No change

        vm.warp(START); // Warp back after demonstrating totalAssets is not time-dependent before vesting starts

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount, vestingPeriod);

        assertEq(pool.freeAssets(), 1_000_000e18);
        assertEq(pool.totalAssets(), 1_000_000e18);
        assertEq(pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert);
        assertEq(pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert);
        assertEq(pool.issuanceRate(), 0.5e18 * 1e30); // 0.5 tokens per second
        assertEq(pool.lastUpdated(), START);
        assertEq(pool.vestingPeriodFinish(), START + vestingPeriod);

        // Warp and assert vesting in 10% increments
        vm.warp(START + 20_000 seconds); // 10% of vesting schedule

        assertEq(pool.balanceOfAssets(address(staker)), 1_010_000e18);
        assertEq(pool.totalAssets(), 1_010_000e18);
        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.01e18);
        assertEq(pool.convertToShares(sampleAssetsToConvert), 9.90099009900990099e17); // Shares go down, as they are worth more assets.

        vm.warp(START + 40_000 seconds); // 20% of vesting schedule

        assertEq(pool.balanceOfAssets(address(staker)), 1_020_000e18);
        assertEq(pool.totalAssets(), 1_020_000e18);
        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.02e18);
        assertEq(pool.convertToShares(sampleAssetsToConvert), 9.80392156862745098e17);

        vm.warp(START + 60_000 seconds); // 30% of vesting schedule

        assertEq(pool.balanceOfAssets(address(staker)), 1_030_000e18);
        assertEq(pool.totalAssets(), 1_030_000e18);
        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.03e18);
        assertEq(pool.convertToShares(sampleAssetsToConvert), 9.7087378640776699e17);

        vm.warp(START + 200_000 seconds); // End of vesting schedule

        assertEq(pool.balanceOfAssets(address(staker)), 1_100_000e18);
        assertEq(pool.totalAssets(), 1_100_000e18);
        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.1e18);
        assertEq(pool.convertToShares(sampleAssetsToConvert), 9.0909090909090909e17);

        assertEq(asset.balanceOf(address(pool)), 1_100_000e18);
        assertEq(asset.balanceOf(address(staker)), 0);
        assertEq(pool.balanceOf(address(staker)), 1_000_000e18);

        staker.pool_redeem(address(pool), 1_000_000e18); // Use `redeem` so pool amount can be used to burn 100% of tokens

        assertEq(pool.freeAssets(), 0);
        assertEq(pool.totalAssets(), 0);
        assertEq(pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert); // returns to sampleAssetsToConvert when empty
        assertEq(pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert); // returns to sampleAssetsToConvert when empty
        assertEq(pool.issuanceRate(), 0.5e18 * 1e30); // TODO: Investigate implications of non-zero issuanceRate here
        assertEq(pool.lastUpdated(), START + 200_000 seconds); // This makes issuanceRate * time zero
        assertEq(pool.vestingPeriodFinish(), START + 200_000 seconds);

        assertEq(asset.balanceOf(address(pool)), 0);
        assertEq(pool.balanceOfAssets(address(staker)), 0);

        assertEq(asset.balanceOf(address(staker)), 1_100_000e18);
        assertEq(pool.balanceOf(address(staker)), 0);
    }

    function test_vesting_singleSchedule_fuzz(uint256 depositAmount, uint256 vestingAmount, uint256 vestingPeriod)
        public
    {
        depositAmount = constrictToRange(depositAmount, 1e6, 1e30); // 1 billion at WAD precision
        vestingAmount = constrictToRange(vestingAmount, 1e6, 1e30); // 1 billion at WAD precision
        vestingPeriod = constrictToRange(vestingPeriod, 10 seconds, 100_000 days) / 10 * 10; // Must be divisible by 10 for for loop 10% increment calculations // TODO: Add a zero case test

        Staker staker = new Staker();

        asset.mint(address(staker), depositAmount);

        staker.erc20_approve(address(asset), address(pool), depositAmount);
        staker.pool_deposit(address(pool), depositAmount);

        assertEq(pool.freeAssets(), depositAmount);
        assertEq(pool.totalAssets(), depositAmount);
        assertEq(pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert);
        assertEq(pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert);
        assertEq(pool.issuanceRate(), 0);
        assertEq(pool.lastUpdated(), START);
        assertEq(pool.vestingPeriodFinish(), 0);

        vm.warp(START + 1 days);

        assertEq(pool.totalAssets(), depositAmount); // No change

        vm.warp(START); // Warp back after demonstrating totalAssets is not time-dependent before vesting starts

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount, vestingPeriod);

        uint256 expectedRate = vestingAmount * 1e30 / vestingPeriod;

        assertEq(pool.freeAssets(), depositAmount);
        assertEq(pool.totalAssets(), depositAmount);
        assertEq(pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert);
        assertEq(pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert);
        assertEq(pool.issuanceRate(), expectedRate);
        assertEq(pool.lastUpdated(), START);
        assertEq(pool.vestingPeriodFinish(), START + vestingPeriod);

        // Warp and assert vesting in 10% increments
        for (uint256 i = 1; i < 10; ++i) {
            vm.warp(START + vestingPeriod * i / 10); // 10% intervals of vesting schedule

            uint256 expectedTotalAssets = depositAmount + expectedRate * (block.timestamp - START) / 1e30;

            assertWithinDiff(pool.balanceOfAssets(address(staker)), expectedTotalAssets, 1);

            assertEq(pool.totalSupply(), depositAmount);
            assertEq(pool.totalAssets(), expectedTotalAssets);
            assertEq(
                pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert * expectedTotalAssets / depositAmount
            );
            assertEq(
                pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert * depositAmount / expectedTotalAssets
            );
        }

        vm.warp(START + vestingPeriod);

        uint256 expectedFinalTotal = depositAmount + vestingAmount;

        // TODO: Try assertEq
        assertWithinDiff(pool.balanceOfAssets(address(staker)), expectedFinalTotal, 2);

        assertWithinDiff(pool.totalAssets(), expectedFinalTotal, 1);
        assertEq(
            pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert * pool.totalAssets() / depositAmount
        ); // Using totalAssets because of rounding
        assertEq(
            pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert * depositAmount / pool.totalAssets()
        );

        assertEq(asset.balanceOf(address(pool)), depositAmount + vestingAmount);

        assertEq(asset.balanceOf(address(staker)), 0);
        assertEq(pool.balanceOf(address(staker)), depositAmount);

        staker.pool_redeem(address(pool), depositAmount); // Use `redeem` so pool amount can be used to burn 100% of tokens

        assertWithinDiff(pool.freeAssets(), 0, 1);
        assertWithinDiff(pool.totalAssets(), 0, 1);

        assertEq(pool.convertToAssets(sampleSharesToConvert), sampleSharesToConvert); // Returns to sampleSharesToConvert zero when empty.
        assertEq(pool.convertToShares(sampleAssetsToConvert), sampleAssetsToConvert); // Returns to sampleAssetsToConvert zero when empty.
        assertEq(pool.issuanceRate(), expectedRate); // TODO: Investigate implications of non-zero issuanceRate here
        assertEq(pool.lastUpdated(), START + vestingPeriod); // This makes issuanceRate * time zero
        assertEq(pool.vestingPeriodFinish(), START + vestingPeriod);

        assertWithinDiff(asset.balanceOf(address(pool)), 0, 2);

        assertEq(pool.balanceOfAssets(address(staker)), 0);

        assertWithinDiff(asset.balanceOf(address(staker)), depositAmount + vestingAmount, 2);
        assertWithinDiff(pool.balanceOf(address(staker)), 0, 1);
    }
}
