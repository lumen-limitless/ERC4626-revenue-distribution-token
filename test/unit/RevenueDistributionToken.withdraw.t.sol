// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.7;

import {ERC20} from "solady/tokens/ERC20.sol";
import {MockRevertingERC20} from "../mocks/MockRevertingERC20.sol";
import {RevenueDistributionToken} from "src/RevenueDistributionToken.sol";
import {BaseTest} from "../base/BaseTest.sol";
import {PoolTestBase} from "../base/PoolTestBase.sol";
import {PoolSuccessTestBase} from "../base/PoolSuccessTestBase.sol";
import {Staker} from "../accounts/Staker.sol";

// =============================================================
//                       WITHDRAW TESTS
// =============================================================

contract WithdrawCallerNotOwnerTests is PoolSuccessTestBase {
    Staker caller;
    Staker staker;

    function setUp() public override {
        super.setUp();
        caller = new Staker();
        staker = new Staker();
    }

    function test_withdraw_callerNotOwner_singleUser_preVesting() public {
        caller = new Staker();
        staker = new Staker();

        _depositAsset(address(asset), address(staker), 1000);

        staker.erc20_approve(address(pool), address(caller), 1000);

        pool_allowance_staker_caller_change = -1000;
        pool_balanceOf_staker_change = -1000;
        pool_totalSupply_change = -1000;
        pool_freeAssets_change = -1000;
        pool_totalAssets_change = -1000;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 0;

        asset_balanceOf_caller_change = 1000;
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -1000;

        _assertWithdrawCallerNotOwner(address(caller), address(staker), 1000, false);
    }

    // TODO: Fuzz approve amount.
    function testFuzz_withdraw_callerNotOwner_singleUser_preVesting(uint256 depositAmount_, uint256 withdrawAmount_)
        public
    {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        withdrawAmount_ = constrictToRange(withdrawAmount_, 1, depositAmount_);

        _depositAsset(address(asset), address(staker), depositAmount_);

        staker.erc20_approve(address(pool), address(caller), withdrawAmount_);

        pool_allowance_staker_caller_change = -_toInt256(withdrawAmount_);
        pool_balanceOf_staker_change = -_toInt256(withdrawAmount_);
        pool_totalSupply_change = -_toInt256(withdrawAmount_);
        pool_freeAssets_change = -_toInt256(withdrawAmount_);
        pool_totalAssets_change = -_toInt256(withdrawAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 0;

        asset_balanceOf_caller_change = _toInt256(withdrawAmount_);
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -_toInt256(withdrawAmount_);

        _assertWithdrawCallerNotOwner(address(caller), address(staker), withdrawAmount_, true);
    }

    function test_withdraw_callerNotOwner_singleUser_midVesting() public {
        _depositAsset(address(asset), address(staker), 100e18);
        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 200 seconds);

        vm.warp(START + 100 seconds); // Vest 5e18 tokens

        staker.erc20_approve(address(pool), address(caller), 19.04761904761904762e18);

        pool_allowance_staker_caller_change = -19.04761904761904762e18;
        pool_balanceOf_staker_change = -19.04761904761904762e18; // 20 / 1.05
        pool_totalSupply_change = -19.04761904761904762e18; // 20 / 1.05
        pool_freeAssets_change = -15e18; // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_totalAssets_change = -20e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 100 seconds;

        asset_balanceOf_caller_change = 20e18;
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -20e18;

        _assertWithdrawCallerNotOwner(address(caller), address(staker), 20e18, false);
    }

    // TODO: Fuzz approve amount.
    function testFuzz_withdraw_callerNotOwner_singleUser_midVesting(
        uint256 depositAmount_,
        uint256 withdrawAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        uint256 warpTime_
    ) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 100 days);
        warpTime_ = constrictToRange(warpTime_, 0, vestingPeriod_);

        _depositAsset(address(asset), address(staker), depositAmount_);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + warpTime_);

        uint256 maxWithdrawAmount = depositAmount_ * pool.totalAssets() / pool.totalSupply();

        withdrawAmount_ = constrictToRange(withdrawAmount_, 1, maxWithdrawAmount);

        uint256 expectedSharesBurned = pool.previewWithdraw(withdrawAmount_);
        uint256 vestedAmount = pool.issuanceRate() * warpTime_ / 1e30;

        staker.erc20_approve(address(pool), address(caller), expectedSharesBurned);

        pool_allowance_staker_caller_change = -_toInt256(expectedSharesBurned);
        pool_balanceOf_staker_change = -_toInt256(expectedSharesBurned);
        pool_totalSupply_change = -_toInt256(expectedSharesBurned);
        pool_totalAssets_change = -_toInt256(withdrawAmount_);
        pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(withdrawAmount_); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(warpTime_);

        asset_balanceOf_caller_change = _toInt256(withdrawAmount_);
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -_toInt256(withdrawAmount_);

        _assertWithdrawCallerNotOwner(address(caller), address(staker), withdrawAmount_, true);
    }

    function test_withdraw_callerNotOwner_singleUser_postVesting() public {
        _depositAsset(address(asset), address(staker), 100e18);
        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 200 seconds);

        vm.warp(START + 201 seconds); // Vest 5e18 tokens

        staker.erc20_approve(address(pool), address(caller), 18.181818181818181819e18);

        pool_allowance_staker_caller_change = -18.181818181818181819e18;
        pool_balanceOf_staker_change = -18.181818181818181819e18; // 20 / 1.1
        pool_totalSupply_change = -18.181818181818181819e18; // 20 / 1.1
        pool_freeAssets_change = -10e18; // freeAssets gets updated to reflects 10e18 vested tokens during withdraw
        pool_totalAssets_change = -20e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -(0.05e18 * 1e30); // Gets set to zero.
        pool_lastUpdated_change = 201 seconds;

        asset_balanceOf_caller_change = 20e18;
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -20e18;

        _assertWithdrawCallerNotOwner(address(caller), address(staker), 20e18, false);
    }

    function testFuzz_withdraw_callerNotOwner_singleUser_postVesting(
        uint256 depositAmount_,
        uint256 withdrawAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_
    ) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 100 days);

        _depositAsset(address(asset), address(staker), depositAmount_);
        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 1 seconds);

        uint256 maxWithdrawAmount = depositAmount_ * pool.totalAssets() / pool.totalSupply();

        withdrawAmount_ = constrictToRange(withdrawAmount_, 1, maxWithdrawAmount);

        uint256 expectedSharesBurned = pool.previewWithdraw(withdrawAmount_);

        staker.erc20_approve(address(pool), address(caller), expectedSharesBurned);

        pool_allowance_staker_caller_change = -_toInt256(expectedSharesBurned);
        pool_balanceOf_staker_change = -_toInt256(expectedSharesBurned);
        pool_totalSupply_change = -_toInt256(expectedSharesBurned);
        pool_totalAssets_change = -_toInt256(withdrawAmount_);
        pool_freeAssets_change = _toInt256(vestingAmount_) - _toInt256(withdrawAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate());
        pool_lastUpdated_change = _toInt256(vestingPeriod_ + 1 seconds);

        asset_balanceOf_caller_change = _toInt256(withdrawAmount_);
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -_toInt256(withdrawAmount_);

        _assertWithdrawCallerNotOwner(address(caller), address(staker), withdrawAmount_, true);
    }

    function testFuzz_withdraw_callerNotOwner_multiUser_midVesting(
        uint256 iterations_,
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 withdrawSeed_,
        bytes32 warpSeed_
    ) public {
        iterations_ = constrictToRange(iterations_, 10, 20);
        initialAmount_ = constrictToRange(initialAmount_, 1e6, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1e6, 1e29);

        uint256 initWarpTime;
        initWarpTime = constrictToRange(initWarpTime, 1 seconds, 100 days);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days + initWarpTime, 1e29);

        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        // Warp into middle of vestingPeriod so exchangeRate is greater than zero for all new deposits
        vm.warp(START + initWarpTime);

        Staker[] memory stakers = new Staker[](iterations_);

        for (uint256 i; i < iterations_; ++i) {
            stakers[i] = new Staker();

            uint256 depositAmount = uint256(keccak256(abi.encodePacked(depositSeed_, i)));

            // Get minimum deposit to avoid ZERO_SHARES.
            uint256 minDeposit = _getMinDeposit(address(pool));
            depositAmount = constrictToRange(depositAmount, minDeposit, 1e29 + 1); // + 1 since we round up in min deposit.

            _depositAsset(address(asset), address(stakers[i]), depositAmount);
        }

        for (uint256 i; i < iterations_; ++i) {
            caller = new Staker();

            uint256 withdrawAmount = uint256(keccak256(abi.encodePacked(withdrawSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            {
                uint256 maxWithdrawAmount =
                    pool.balanceOf(address(stakers[i])) * pool.totalAssets() / pool.totalSupply();
                withdrawAmount = constrictToRange(withdrawAmount, 1, maxWithdrawAmount);
            }

            warpTime = constrictToRange(warpTime, 0, (vestingPeriod_ - initWarpTime) / iterations_);

            vm.warp(block.timestamp + warpTime);

            uint256 expectedSharesBurned = pool.previewWithdraw(withdrawAmount);
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            stakers[i].erc20_approve(address(pool), address(caller), expectedSharesBurned);

            pool_allowance_staker_caller_change = -_toInt256(expectedSharesBurned);
            pool_balanceOf_staker_change = -_toInt256(expectedSharesBurned);
            pool_totalSupply_change = -_toInt256(expectedSharesBurned);
            pool_totalAssets_change = -_toInt256(withdrawAmount);
            pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(withdrawAmount); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_caller_change = _toInt256(withdrawAmount);
            asset_balanceOf_staker_change = 0;
            asset_balanceOf_pool_change = -_toInt256(withdrawAmount);

            _assertWithdrawCallerNotOwner(address(caller), address(stakers[i]), withdrawAmount, true);
        }
    }

    function testFuzz_withdraw_callerNotOwner_multiUser_postVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 withdrawSeed_,
        bytes32 warpSeed_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1e6, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1e6, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days, 1e29);

        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 12 hours); // Warp into vestingPeriod so exchangeRate is greater than one for all new deposits

        Staker[] memory stakers = new Staker[](10);

        for (uint256 i; i < 10; ++i) {
            stakers[i] = new Staker();

            uint256 depositAmount = uint256(keccak256(abi.encodePacked(depositSeed_, i)));

            // Get minimum deposit to avoid ZERO_SHARES.
            uint256 minDeposit = _getMinDeposit(address(pool));
            depositAmount = constrictToRange(depositAmount, minDeposit, 1e29 + 1); // + 1 since we round up in min deposit.

            _depositAsset(address(asset), address(stakers[i]), depositAmount);
        }

        for (uint256 i; i < 10; ++i) {
            caller = new Staker();

            uint256 withdrawAmount = uint256(keccak256(abi.encodePacked(withdrawSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            uint256 maxWithdrawAmount = pool.balanceOf(address(stakers[i])) * pool.totalAssets() / pool.totalSupply();

            withdrawAmount = constrictToRange(withdrawAmount, 1, maxWithdrawAmount);
            warpTime = constrictToRange(warpTime, 0, (vestingPeriod_ - 12 hours) / 10);

            vm.warp(block.timestamp + warpTime);

            uint256 expectedSharesBurned = pool.previewWithdraw(withdrawAmount);
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            stakers[i].erc20_approve(address(pool), address(caller), expectedSharesBurned);

            pool_allowance_staker_caller_change = -_toInt256(expectedSharesBurned);
            pool_balanceOf_staker_change = -_toInt256(expectedSharesBurned);
            pool_totalSupply_change = -_toInt256(expectedSharesBurned);
            pool_totalAssets_change = -_toInt256(withdrawAmount);
            pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(withdrawAmount); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_caller_change = _toInt256(withdrawAmount);
            asset_balanceOf_staker_change = 0;
            asset_balanceOf_pool_change = -_toInt256(withdrawAmount);

            _assertWithdrawCallerNotOwner(address(caller), address(stakers[i]), withdrawAmount, true);
        }
    }
}

contract WithdrawFailureTests is PoolTestBase {
    Staker staker;

    function setUp() public virtual override {
        super.setUp();
        staker = new Staker();
    }

    function test_withdraw_zeroAmount(uint256 depositAmount_) public {
        _depositAsset(address(asset), address(staker), depositAmount_ = constrictToRange(depositAmount_, 1, 1e29));

        vm.expectRevert();
        staker.pool_withdraw(address(pool), 0);

        staker.pool_withdraw(address(pool), 1);
    }

    function test_withdraw_burnUnderflow(uint256 depositAmount_) public {
        _depositAsset(address(asset), address(staker), depositAmount_ = constrictToRange(depositAmount_, 1, 1e29));

        vm.expectRevert();
        staker.pool_withdraw(address(pool), depositAmount_ + 1);

        staker.pool_withdraw(address(pool), depositAmount_);
    }

    function test_withdraw_burnUnderflow_totalAssetsGtTotalSupply_explicitValues() public {
        uint256 depositAmount = 100e18;
        uint256 vestingAmount = 10e18;
        uint256 vestingPeriod = 10 days;
        uint256 warpTime = 5 days;

        _depositAsset(address(asset), address(staker), depositAmount);
        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount, vestingPeriod);

        vm.warp(block.timestamp + warpTime);

        uint256 maxWithdrawAmount = pool.previewRedeem(pool.balanceOf(address(staker))); // TODO

        vm.expectRevert();
        staker.pool_withdraw(address(pool), maxWithdrawAmount + 1);

        staker.pool_withdraw(address(pool), maxWithdrawAmount);
    }

    function test_withdraw_callerNotOwner_badApproval() public {
        Staker shareOwner = new Staker();
        Staker notShareOwner = new Staker();

        uint256 depositAmount = 1e18;
        asset.mint(address(shareOwner), depositAmount);

        shareOwner.erc20_approve(address(asset), address(pool), depositAmount);
        shareOwner.pool_deposit(address(pool), depositAmount);

        shareOwner.erc20_approve(address(pool), address(notShareOwner), depositAmount - 1);
        vm.expectRevert();
        notShareOwner.pool_withdraw(address(pool), depositAmount, address(shareOwner), address(shareOwner));

        shareOwner.erc20_approve(address(pool), address(notShareOwner), depositAmount);

        assertEq(pool.allowance(address(shareOwner), address(notShareOwner)), depositAmount);

        notShareOwner.pool_withdraw(address(pool), depositAmount, address(notShareOwner), address(shareOwner));

        assertEq(pool.allowance(address(shareOwner), address(notShareOwner)), 0);
    }

    function test_withdraw_callerNotOwner_infiniteApprovalForCaller() public {
        Staker shareOwner = new Staker();
        Staker notShareOwner = new Staker();

        uint256 depositAmount = 1e18;
        asset.mint(address(shareOwner), depositAmount);

        shareOwner.erc20_approve(address(asset), address(pool), depositAmount);
        shareOwner.pool_deposit(address(pool), depositAmount);

        shareOwner.erc20_approve(address(pool), address(notShareOwner), type(uint256).max);

        assertEq(pool.allowance(address(shareOwner), address(notShareOwner)), type(uint256).max);

        notShareOwner.pool_withdraw(address(pool), depositAmount, address(notShareOwner), address(shareOwner));

        // Infinite approval stays infinite.
        assertEq(pool.allowance(address(shareOwner), address(notShareOwner)), type(uint256).max);
    }

    function test_withdraw_burnUnderflow_totalAssetsGtTotalSupply(
        uint256 depositAmount,
        uint256 vestingAmount,
        uint256 vestingPeriod,
        uint256 warpTime
    ) public {
        depositAmount = constrictToRange(depositAmount, 1, 1e29);
        vestingAmount = constrictToRange(vestingAmount, 1, 1e29);
        vestingPeriod = constrictToRange(vestingPeriod, 1, 100 days);
        warpTime = constrictToRange(vestingAmount, 1, vestingPeriod);

        _depositAsset(address(asset), address(staker), depositAmount);
        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount, vestingPeriod);

        vm.warp(block.timestamp + warpTime);

        uint256 underflowWithdrawAmount = pool.previewRedeem(pool.balanceOf(address(staker)) + 1); // TODO
        uint256 maxWithdrawAmount = pool.previewRedeem(pool.balanceOf(address(staker))); // TODO

        vm.expectRevert();
        staker.pool_withdraw(address(pool), underflowWithdrawAmount);

        staker.pool_withdraw(address(pool), maxWithdrawAmount);
    }
}

// contract WithdrawRevertOnTransfers is PoolTestBase {
//     MockRevertingERC20 revertingAsset;
//     Staker staker;

//     function setUp() public virtual override {
//         revertingAsset = new MockRevertingERC20("MockToken", "MT", 18, address(123));
//         pool = new RevenueDistributionToken(address(this), address(revertingAsset), 1e30, "TEST POOL", "TEST");
//         staker = new Staker();

//         vm.warp(START); // Warp to non-zero timestamp
//     }

//     function test_withdraw_revertOnTransfer(uint256 depositAmount_, uint256 withdrawAmount_) public {
//         depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
//         withdrawAmount_ = constrictToRange(withdrawAmount_, 1, depositAmount_);

//         revertingAsset.mint(address(staker), depositAmount_);

//         staker.erc20_approve(address(revertingAsset), address(pool), depositAmount_);
//         staker.pool_deposit(address(pool), depositAmount_);

//         vm.warp(START + 10 days);

//         address revertingDestination = revertingAsset.revertingDestination();
//         vm.expectRevert();
//         staker.pool_withdraw(address(pool), withdrawAmount_, revertingDestination, address(staker));

//         staker.pool_withdraw(address(pool), withdrawAmount_, address(1), address(staker));
//     }
// }

contract WithdrawTests is PoolSuccessTestBase {
    function test_withdraw_singleUser_preVesting() public {
        address staker = vm.addr(1);

        _depositAsset(address(asset), staker, 1000);

        pool_balanceOf_staker_change = -1000;
        pool_totalSupply_change = -1000;
        pool_freeAssets_change = -1000;
        pool_totalAssets_change = -1000;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 0;

        asset_balanceOf_staker_change = 1000;
        asset_balanceOf_pool_change = -1000;

        _assertWithdraw(staker, 1000, false);
    }

    function testFuzz_withdraw_singleUser_preVesting(uint256 depositAmount_, uint256 withdrawAmount_) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        withdrawAmount_ = constrictToRange(withdrawAmount_, 1, depositAmount_);

        address staker = vm.addr(1);

        _depositAsset(address(asset), staker, depositAmount_);

        pool_balanceOf_staker_change = -_toInt256(withdrawAmount_);
        pool_totalSupply_change = -_toInt256(withdrawAmount_);
        pool_freeAssets_change = -_toInt256(withdrawAmount_);
        pool_totalAssets_change = -_toInt256(withdrawAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 0;

        asset_balanceOf_staker_change = _toInt256(withdrawAmount_);
        asset_balanceOf_pool_change = -_toInt256(withdrawAmount_);

        _assertWithdraw(staker, withdrawAmount_, true);
    }

    function test_withdraw_singleUser_midVesting() public {
        address staker = vm.addr(1);

        _depositAsset(address(asset), staker, 100e18);
        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 200 seconds);

        vm.warp(block.timestamp + 100 seconds); // Vest 5e18 tokens

        pool_balanceOf_staker_change = -19.04761904761904762e18; // 20 / 1.05
        pool_totalSupply_change = -19.04761904761904762e18; // 20 / 1.05
        pool_freeAssets_change = -15e18; // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_totalAssets_change = -20e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 100 seconds;

        asset_balanceOf_staker_change = 20e18;
        asset_balanceOf_pool_change = -20e18;

        _assertWithdraw(staker, 20e18, false);
    }

    function testFuzz_withdraw_singleUser_midVesting(
        uint256 depositAmount_,
        uint256 withdrawAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        uint256 warpTime_
    ) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 100 days);
        warpTime_ = constrictToRange(warpTime_, 0, vestingPeriod_);

        address staker = vm.addr(1);

        _depositAsset(address(asset), staker, depositAmount_);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + warpTime_);

        uint256 maxWithdrawAmount = depositAmount_ * pool.totalAssets() / pool.totalSupply();

        withdrawAmount_ = constrictToRange(withdrawAmount_, 1, maxWithdrawAmount);

        uint256 expectedSharesBurned = pool.previewWithdraw(withdrawAmount_);
        uint256 vestedAmount = pool.issuanceRate() * warpTime_ / 1e30;

        pool_balanceOf_staker_change = -_toInt256(expectedSharesBurned);
        pool_totalSupply_change = -_toInt256(expectedSharesBurned);
        pool_totalAssets_change = -_toInt256(withdrawAmount_);
        pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(withdrawAmount_); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(warpTime_);

        asset_balanceOf_staker_change = _toInt256(withdrawAmount_);
        asset_balanceOf_pool_change = -_toInt256(withdrawAmount_);

        _assertWithdraw(staker, withdrawAmount_, true);
    }

    function test_withdraw_singleUser_postVesting() public {
        address staker = vm.addr(1);

        _depositAsset(address(asset), staker, 100e18);
        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 200 seconds);

        vm.warp(START + 201 seconds); // Vest 5e18 tokens

        pool_balanceOf_staker_change = -18.181818181818181819e18; // 20 / 1.1
        pool_totalSupply_change = -18.181818181818181819e18; // 20 / 1.1
        pool_freeAssets_change = -10e18; // freeAssets gets updated to reflects 10e18 vested tokens during withdraw
        pool_totalAssets_change = -20e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -(0.05e18 * 1e30); // Gets set to zero.
        pool_lastUpdated_change = 201 seconds;

        asset_balanceOf_staker_change = 20e18;
        asset_balanceOf_pool_change = -20e18;

        _assertWithdraw(staker, 20e18, false);
    }

    function testFuzz_withdraw_singleUser_postVesting(
        uint256 depositAmount_,
        uint256 withdrawAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_
    ) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 100 days);

        address staker = vm.addr(1);

        _depositAsset(address(asset), staker, depositAmount_);
        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 1 seconds);

        uint256 maxWithdrawAmount = depositAmount_ * pool.totalAssets() / pool.totalSupply();

        withdrawAmount_ = constrictToRange(withdrawAmount_, 1, maxWithdrawAmount);

        uint256 expectedSharesBurned = pool.previewWithdraw(withdrawAmount_);

        pool_balanceOf_staker_change = -_toInt256(expectedSharesBurned);
        pool_totalSupply_change = -_toInt256(expectedSharesBurned);
        pool_totalAssets_change = -_toInt256(withdrawAmount_);
        pool_freeAssets_change = _toInt256(vestingAmount_) - _toInt256(withdrawAmount_); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate());
        pool_lastUpdated_change = _toInt256(vestingPeriod_ + 1 seconds);

        asset_balanceOf_staker_change = _toInt256(withdrawAmount_);
        asset_balanceOf_pool_change = -_toInt256(withdrawAmount_);

        _assertWithdraw(staker, withdrawAmount_, true);
    }

    function testFuzz_withdraw_multiUser_midVesting(
        uint256 iterations_,
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 withdrawSeed_,
        bytes32 warpSeed_
    ) public {
        iterations_ = constrictToRange(iterations_, 10, 20);
        initialAmount_ = constrictToRange(initialAmount_, 1e6, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1e6, 1e29);

        uint256 initWarpTime;
        initWarpTime = constrictToRange(initWarpTime, 1 seconds, 100 days);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days + initWarpTime, 1e29);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        // Warp into middle of vestingPeriod so exchangeRate is greater than zero for all new deposits
        vm.warp(START + initWarpTime);

        Staker[] memory stakers = new Staker[](iterations_);

        for (uint256 i; i < iterations_; ++i) {
            stakers[i] = new Staker();

            uint256 depositAmount = uint256(keccak256(abi.encodePacked(depositSeed_, i)));

            // Get minimum deposit to avoid ZERO_SHARES.
            uint256 minDeposit = _getMinDeposit(address(pool));
            depositAmount = constrictToRange(depositAmount, minDeposit, 1e29 + 1); // + 1 since we round up in min deposit.

            _depositAsset(address(asset), address(stakers[i]), depositAmount);
        }

        for (uint256 i; i < iterations_; ++i) {
            uint256 withdrawAmount = uint256(keccak256(abi.encodePacked(withdrawSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            // Scoped to prevent stack too deep.
            {
                uint256 maxWithdrawAmount =
                    pool.balanceOf(address(stakers[i])) * pool.totalAssets() / pool.totalSupply();
                withdrawAmount = constrictToRange(withdrawAmount, 1, maxWithdrawAmount);
            }

            warpTime = constrictToRange(warpTime, 0, (vestingPeriod_ - initWarpTime) / iterations_);

            vm.warp(block.timestamp + warpTime);

            uint256 expectedSharesBurned = pool.previewWithdraw(withdrawAmount);
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            pool_balanceOf_staker_change = -_toInt256(expectedSharesBurned);
            pool_totalSupply_change = -_toInt256(expectedSharesBurned);
            pool_totalAssets_change = -_toInt256(withdrawAmount);
            pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(withdrawAmount); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_staker_change = _toInt256(withdrawAmount);
            asset_balanceOf_pool_change = -_toInt256(withdrawAmount);

            _assertWithdraw(address(stakers[i]), withdrawAmount, true);
        }
    }

    function testFuzz_withdraw_multiUser_postVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 withdrawSeed_,
        bytes32 warpSeed_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1e6, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1e6, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days, 1e29);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 12 hours); // Warp into vestingPeriod so exchangeRate is greater than zero for all new deposits

        Staker[] memory stakers = new Staker[](10);

        for (uint256 i; i < 10; ++i) {
            stakers[i] = new Staker();

            uint256 depositAmount = uint256(keccak256(abi.encodePacked(depositSeed_, i)));

            // Get minimum deposit to avoid ZERO_SHARES.
            uint256 minDeposit = _getMinDeposit(address(pool));
            depositAmount = constrictToRange(depositAmount, minDeposit, 1e29 + 1); // + 1 since we round up in min deposit.

            _depositAsset(address(asset), address(stakers[i]), depositAmount);
        }

        for (uint256 i; i < 10; ++i) {
            uint256 withdrawAmount = uint256(keccak256(abi.encodePacked(withdrawSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            uint256 maxWithdrawAmount = pool.balanceOf(address(stakers[i])) * pool.totalAssets() / pool.totalSupply();

            withdrawAmount = constrictToRange(withdrawAmount, 1, maxWithdrawAmount);
            warpTime = constrictToRange(warpTime, 0, (vestingPeriod_ - 12 hours) / 10);

            vm.warp(block.timestamp + warpTime);

            uint256 expectedSharesBurned = pool.previewWithdraw(withdrawAmount);
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            pool_balanceOf_staker_change = -_toInt256(expectedSharesBurned);
            pool_totalSupply_change = -_toInt256(expectedSharesBurned);
            pool_totalAssets_change = -_toInt256(withdrawAmount);
            pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(withdrawAmount); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_staker_change = _toInt256(withdrawAmount);
            asset_balanceOf_pool_change = -_toInt256(withdrawAmount);

            _assertWithdraw(address(stakers[i]), withdrawAmount, true);
        }
    }
}
