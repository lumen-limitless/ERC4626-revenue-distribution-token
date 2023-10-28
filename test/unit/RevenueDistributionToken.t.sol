// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {ERC20} from "../../src/ERC20.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockRevertingERC20} from "../mocks/MockRevertingERC20.sol";
import {MockRevenueDistributionToken} from "../mocks/MockRevenueDistributionToken.sol";
import {BaseTest} from "../base/BaseTest.sol";
import {PoolTestBase} from "../base/PoolTestBase.sol";
import {PoolSuccessTestBase} from "../base/PoolSuccessTestBase.sol";
import {Staker} from "../accounts/Staker.sol";

contract RevenueDistributionTokenTests is PoolTestBase {
    function testFuzz_deposit(uint128 amount_, uint56 warpTime) public {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        uint256 amount = amount_;

        // deploy fresh pool
        MockRevenueDistributionToken pool_ = new MockRevenueDistributionToken(address(this), address(asset), 1e30);

        vm.startPrank(TESTER);

        // warp to future
        vm.warp(START + uint256(warpTime));

        // mint stake tokens
        asset.mint(TESTER, amount);

        // stake
        uint256 beforepoolAssetBalance = asset.balanceOf(address(pool_));
        asset.approve(address(pool_), amount);
        uint256 shareAmount = pool_.deposit(amount, TESTER);

        // check balances
        // took stake tokens from tester to staking pool
        assertEqDecimal(asset.balanceOf(TESTER), 0, 18);
        assertEqDecimal(asset.balanceOf(address(pool_)) - beforepoolAssetBalance, amount, 18);
        // gave correct share amount
        assertEqDecimal(shareAmount, pool_.convertToShares(amount_), 18);
        assertEqDecimal(pool_.balanceOf(TESTER), shareAmount, 18);
    }

    function testFuzz_mint(uint128 amount_, uint56 warpTime) public {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        uint256 amount = amount_;

        // deploy fresh pool
        MockRevenueDistributionToken pool_ = new MockRevenueDistributionToken(address(this), address(asset), 1e30);

        vm.startPrank(TESTER);

        // warp to future
        vm.warp(START + uint256(warpTime));

        // mint stake tokens
        asset.mint(TESTER, amount);

        // stake
        uint256 beforepoolAssetBalance = asset.balanceOf(address(pool_));
        asset.approve(address(pool_), amount);
        uint256 shareAmount = pool_.mint(amount, TESTER);

        // check balances
        // took stake tokens from tester to staking pool
        assertEqDecimal(asset.balanceOf(TESTER), 0, 18);
        assertEqDecimal(asset.balanceOf(address(pool_)) - beforepoolAssetBalance, amount, 18);
        // gave correct share amount
        assertEqDecimal(shareAmount, pool_.convertToShares(amount_), 18);
        assertEqDecimal(pool_.balanceOf(TESTER), shareAmount, 18);
    }

    function testFuzz_withdraw(uint128 amount_, uint56 warpTime, uint56 stakeTime) public {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        vm.assume(stakeTime > 0);
        uint256 amount = amount_;

        // deploy fresh pool
        MockRevenueDistributionToken pool_ = new MockRevenueDistributionToken(address(this), address(asset), 1e30);

        vm.startPrank(TESTER);

        // warp to future
        vm.warp(START + warpTime);

        // mint stake tokens
        asset.mint(TESTER, amount);

        // stake
        uint256 beforeStakingTesterAssetBalance = asset.balanceOf(TESTER);
        uint256 beforepoolAssetBalance = asset.balanceOf(address(pool_));
        asset.approve(address(pool_), amount);
        uint256 shareAmount = pool_.deposit(amount, TESTER);

        // warp to simulate staking
        vm.warp(START + uint256(warpTime) + uint256(stakeTime));

        // withdraw
        pool_.withdraw(shareAmount, TESTER, TESTER);

        // check balance
        // staking and unstaking didn't change tester stake token balance in aggregate
        assertEqDecimal(asset.balanceOf(TESTER), beforeStakingTesterAssetBalance, 18);
        // staking and unstaking didn't change the staking pool's stake token balance in aggregate
        assertLeDecimal(asset.balanceOf(address(pool_)) - beforepoolAssetBalance, beforepoolAssetBalance / 1e18, 18);
        // burnt shares of tester
        assertEqDecimal(pool_.balanceOf(TESTER), 0, 18);
    }

    function testFuzz_redeem(uint128 amount_, uint32 warpTime, uint56 stakeTime) public {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        vm.assume(stakeTime > 0);
        uint256 amount = amount_;

        // deploy fresh pool
        MockRevenueDistributionToken pool_ = new MockRevenueDistributionToken(address(this), address(asset), 1e30);

        vm.startPrank(TESTER);

        // warp to future
        vm.warp(START + uint256(warpTime));

        // mint stake tokens
        asset.mint(TESTER, amount);

        // stake
        uint256 beforeStakingTesterAssetBalance = asset.balanceOf(TESTER);
        uint256 beforepoolAssetBalance = asset.balanceOf(address(pool_));
        asset.approve(address(pool_), amount);
        uint256 shareAmount = pool_.deposit(amount, TESTER);

        // warp to simulate staking
        vm.warp(START + uint256(warpTime) + uint256(stakeTime));

        // redeem
        pool_.redeem(shareAmount, TESTER, TESTER);

        // check balance
        // staking and unstaking didn't change tester stake token balance in aggregate
        assertEqDecimal(asset.balanceOf(TESTER), beforeStakingTesterAssetBalance, 18);
        // staking and unstaking didn't change the staking pool's stake token balance in aggregate
        assertLeDecimal(asset.balanceOf(address(pool_)) - beforepoolAssetBalance, beforepoolAssetBalance / 1e18, 18);
        // burnt xERC20 tokens of tester
        assertEqDecimal(pool_.balanceOf(TESTER), 0, 18);
    }

    function testFuzz_updateVestingSchedule(uint128 amount_, uint56 warpTime, uint8 stakeTimeAsDurationPercentage)
        public
    {
        vm.assume(amount_ > 0);
        vm.assume(warpTime > 0);
        vm.assume(stakeTimeAsDurationPercentage > 0);

        // deploy fresh pool
        MockRevenueDistributionToken pool_ = new MockRevenueDistributionToken(address(this), address(asset), 1e30);
        asset.mint(address(this), 1 ether);
        asset.approve(address(pool_), type(uint256).max);
        pool_.deposit(1 ether, address(this));

        uint256 amount = amount_;

        // warp to some time in the future
        vm.warp(START + uint256(warpTime));

        // mint stake token
        asset.mint(address(this), amount);

        // notify new rewards
        uint256 beforeTotalPoolValue = pool_.totalAssets();
        asset.transfer(address(pool_), amount);
        pool_.updateVestingSchedule(DURATION);

        // warp to simulate staking
        uint256 stakeTime = (DURATION * uint256(stakeTimeAsDurationPercentage)) / 100;
        vm.warp(START + uint256(warpTime) + stakeTime);

        // check assertions
        uint256 expectedRewardAmount;
        if (stakeTime >= DURATION) {
            // past second reward period, all rewards have been distributed
            expectedRewardAmount = amount;
        } else {
            // during second reward period, rewards are partially distributed
            expectedRewardAmount = (amount * stakeTimeAsDurationPercentage) / 100;
        }
        uint256 rewardAmount = pool_.totalAssets() - beforeTotalPoolValue;
        assertWithinDiff(rewardAmount, expectedRewardAmount, 1e4);
    }

    function testFuzz_permit(uint128 amount_, uint56 sk_, uint56 warpTime) public {
        vm.assume(amount_ > 0);
        vm.assume(sk_ > 0);
        vm.assume(warpTime > 0);

        uint256 amount = amount_;
        address owner_ = vm.addr(sk_);

        // deploy fresh pool
        MockRevenueDistributionToken pool_ = new MockRevenueDistributionToken(address(this), address(asset), 1e30);

        vm.startPrank(owner_);

        // warp to future
        vm.warp(START + uint256(warpTime));

        asset.mint(owner_, amount);

        asset.approve(address(pool_), amount);

        uint256 shareAmount = pool_.deposit(amount, owner_);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            sk_,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    pool_.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner_, TESTER, shareAmount, 0, block.timestamp))
                )
            )
        );

        pool_.permit(owner_, TESTER, shareAmount, block.timestamp, v, r, s);

        assertEqDecimal(pool_.allowance(owner_, TESTER), shareAmount, 18);

        assertEq(pool_.nonces(owner_), 1);
    }
}
