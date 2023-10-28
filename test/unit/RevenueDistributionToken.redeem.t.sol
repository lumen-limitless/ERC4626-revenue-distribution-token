// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {ERC20} from "../../src/ERC20.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockRevertingERC20} from "../mocks/MockRevertingERC20.sol";
import {RevenueDistributionToken} from "src/RevenueDistributionToken.sol";
import {BaseTest} from "../base/BaseTest.sol";
import {PoolTestBase} from "../base/PoolTestBase.sol";
import {PoolSuccessTestBase} from "../base/PoolSuccessTestBase.sol";
import {Staker} from "../accounts/Staker.sol";
// =============================================================
//                       REDEEM TESTS
// =============================================================

contract RedeemCallerNotOwnerTests is PoolSuccessTestBase {
    Staker caller;
    Staker staker;

    function setUp() public override {
        super.setUp();
        caller = new Staker();
        staker = new Staker();
    }

    function test_redeem_callerNotOwner_singleUser_preVesting() public {
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

        _assertRedeemCallerNotOwner(address(caller), address(staker), 1000, false);
    }

    // TODO: Fuzz approve amount.
    function testFuzz_redeem_callerNotOwner_singleUser_preVesting(uint256 depositAmount_, uint256 redeemAmount_)
        public
    {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        redeemAmount_ = constrictToRange(redeemAmount_, 1, depositAmount_);

        _depositAsset(address(asset), address(staker), depositAmount_);

        staker.erc20_approve(address(pool), address(caller), redeemAmount_);

        pool_allowance_staker_caller_change = -_toInt256(redeemAmount_);
        pool_balanceOf_staker_change = -_toInt256(redeemAmount_);
        pool_totalSupply_change = -_toInt256(redeemAmount_);
        pool_freeAssets_change = -_toInt256(redeemAmount_);
        pool_totalAssets_change = -_toInt256(redeemAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 0;

        asset_balanceOf_caller_change = _toInt256(redeemAmount_);
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -_toInt256(redeemAmount_);

        _assertRedeemCallerNotOwner(address(caller), address(staker), redeemAmount_, true);
    }

    function test_redeem_callerNotOwner_singleUser_midVesting() public {
        _depositAsset(address(asset), address(staker), 100e18);
        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 200 seconds);

        vm.warp(START + 100 seconds); // Vest 5e18 tokens

        staker.erc20_approve(address(pool), address(caller), 20e18);

        pool_allowance_staker_caller_change = -20e18;
        pool_balanceOf_staker_change = -20e18;
        pool_totalSupply_change = -20e18;
        pool_freeAssets_change = -16e18; // freeAssets gets updated to reflects 5e18 vested tokens during withdraw (+5 - 21)
        pool_totalAssets_change = -21e18; // 20 * 1.05
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 100 seconds;

        asset_balanceOf_caller_change = 21e18;
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -21e18;

        _assertRedeemCallerNotOwner(address(caller), address(staker), 20e18, false);
    }

    // TODO: Fuzz approve amount.
    function testFuzz_redeem_callerNotOwner_singleUser_midVesting(
        uint256 depositAmount_,
        uint256 redeemAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        uint256 warpTime_
    ) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        redeemAmount_ = constrictToRange(redeemAmount_, 1, depositAmount_);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1, 100 days);
        warpTime_ = constrictToRange(warpTime_, 1, vestingPeriod_);

        _depositAsset(address(asset), address(staker), depositAmount_);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + warpTime_);

        uint256 expectedWithdrawnFunds = redeemAmount_ * pool.totalAssets() / pool.totalSupply();
        uint256 vestedAmount = pool.issuanceRate() * warpTime_ / 1e30;

        staker.erc20_approve(address(pool), address(caller), redeemAmount_);

        pool_allowance_staker_caller_change = -_toInt256(redeemAmount_);
        pool_balanceOf_staker_change = -_toInt256(redeemAmount_);
        pool_totalSupply_change = -_toInt256(redeemAmount_);
        pool_totalAssets_change = -_toInt256(expectedWithdrawnFunds);
        pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(expectedWithdrawnFunds); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(warpTime_);

        asset_balanceOf_caller_change = _toInt256(expectedWithdrawnFunds);
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -_toInt256(expectedWithdrawnFunds);

        _assertRedeemCallerNotOwner(address(caller), address(staker), redeemAmount_, true);
    }

    function test_redeem_callerNotOwner_singleUser_postVesting() public {
        _depositAsset(address(asset), address(staker), 100e18);
        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 200 seconds);

        vm.warp(START + 201 seconds); // Vest 5e18 tokens

        staker.erc20_approve(address(pool), address(caller), 20e18);

        pool_allowance_staker_caller_change = -20e18;
        pool_balanceOf_staker_change = -20e18;
        pool_totalSupply_change = -20e18;
        pool_freeAssets_change = -12e18; // freeAssets gets updated to reflects 10e18 vested tokens during withdraw (+10 - 22)
        pool_totalAssets_change = -22e18; // 20 * 1.1
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -(0.05e18 * 1e30); // Gets set to zero.
        pool_lastUpdated_change = 201 seconds;

        asset_balanceOf_caller_change = 22e18;
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -22e18;

        _assertRedeemCallerNotOwner(address(caller), address(staker), 20e18, false);
    }

    function testFuzz_redeem_callerNotOwner_singleUser_postVesting(
        uint256 depositAmount_,
        uint256 redeemAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_
    ) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        redeemAmount_ = constrictToRange(redeemAmount_, 1, depositAmount_);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1, 100 days);

        _depositAsset(address(asset), address(staker), depositAmount_);
        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 1 seconds);

        uint256 expectedWithdrawnFunds = pool.previewRedeem(redeemAmount_);

        staker.erc20_approve(address(pool), address(caller), redeemAmount_);

        pool_allowance_staker_caller_change = -_toInt256(redeemAmount_);
        pool_balanceOf_staker_change = -_toInt256(redeemAmount_);
        pool_totalSupply_change = -_toInt256(redeemAmount_);
        pool_totalAssets_change = -_toInt256(expectedWithdrawnFunds);
        pool_freeAssets_change = _toInt256(vestingAmount_) - _toInt256(expectedWithdrawnFunds); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(vestingPeriod_ + 1 seconds);

        asset_balanceOf_caller_change = _toInt256(expectedWithdrawnFunds);
        asset_balanceOf_staker_change = 0;
        asset_balanceOf_pool_change = -_toInt256(expectedWithdrawnFunds);

        _assertRedeemCallerNotOwner(address(caller), address(staker), redeemAmount_, true);
    }

    function testFuzz_redeem_callerNotOwner_multiUser_midVesting(
        uint256 iterations_,
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 redeemSeed_,
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

            uint256 redeemAmount = uint256(keccak256(abi.encodePacked(redeemSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            redeemAmount = constrictToRange(redeemAmount, 1, pool.balanceOf(address(stakers[i])));
            warpTime = constrictToRange(warpTime, 0, (vestingPeriod_ - initWarpTime) / iterations_);

            vm.warp(block.timestamp + warpTime);

            uint256 expectedWithdrawnFunds = pool.previewRedeem(redeemAmount);
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            stakers[i].erc20_approve(address(pool), address(caller), redeemAmount);

            pool_allowance_staker_caller_change = -_toInt256(redeemAmount);
            pool_balanceOf_staker_change = -_toInt256(redeemAmount);
            pool_totalSupply_change = -_toInt256(redeemAmount);
            pool_totalAssets_change = -_toInt256(expectedWithdrawnFunds);
            pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(expectedWithdrawnFunds); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_caller_change = _toInt256(expectedWithdrawnFunds);
            asset_balanceOf_staker_change = 0;
            asset_balanceOf_pool_change = -_toInt256(expectedWithdrawnFunds);

            _assertRedeemCallerNotOwner(address(caller), address(stakers[i]), redeemAmount, true);
        }
    }

    function testFuzz_redeem_callerNotOwner_multiUser_postVesting(
        uint256 iterations_,
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 redeemSeed_,
        bytes32 warpSeed_
    ) public {
        iterations_ = constrictToRange(iterations_, 10, 20);
        initialAmount_ = constrictToRange(initialAmount_, 1e6, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1e6, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days, 1e29);

        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 12 hours); // Warp into vestingPeriod so exchangeRate is greater than one for all new deposits

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

            uint256 redeemAmount = uint256(keccak256(abi.encodePacked(redeemSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            redeemAmount = constrictToRange(redeemAmount, 1, pool.balanceOf(address(stakers[i])));
            warpTime = constrictToRange(warpTime, 0, (vestingPeriod_ - 12 hours) / iterations_);

            vm.warp(block.timestamp + warpTime);

            uint256 expectedWithdrawnFunds = pool.previewRedeem(redeemAmount);
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            stakers[i].erc20_approve(address(pool), address(caller), redeemAmount);

            pool_allowance_staker_caller_change = -_toInt256(redeemAmount);
            pool_balanceOf_staker_change = -_toInt256(redeemAmount);
            pool_totalSupply_change = -_toInt256(redeemAmount);
            pool_totalAssets_change = -_toInt256(expectedWithdrawnFunds);
            pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(expectedWithdrawnFunds); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_caller_change = _toInt256(expectedWithdrawnFunds);
            asset_balanceOf_staker_change = 0;
            asset_balanceOf_pool_change = -_toInt256(expectedWithdrawnFunds);

            _assertRedeemCallerNotOwner(address(caller), address(stakers[i]), redeemAmount, true);
        }
    }
}

contract RedeemFailureTests is PoolTestBase {
    Staker staker;

    function setUp() public virtual override {
        super.setUp();
        staker = new Staker();
    }

    function test_redeem_zeroShares(uint256 depositAmount_) public {
        _depositAsset(address(asset), address(staker), depositAmount_ = constrictToRange(depositAmount_, 1, 1e29));

        vm.expectRevert();
        staker.pool_redeem(address(pool), 0);

        staker.pool_redeem(address(pool), 1);
    }

    function test_redeem_burnUnderflow(uint256 depositAmount_) public {
        _depositAsset(address(asset), address(staker), depositAmount_ = constrictToRange(depositAmount_, 1, 1e29));

        vm.expectRevert();
        staker.pool_redeem(address(pool), depositAmount_ + 1);

        staker.pool_redeem(address(pool), depositAmount_);
    }

    function test_redeem_burnUnderflow_totalAssetsGtTotalSupply_explicitValues() public {
        uint256 depositAmount = 100e18;
        uint256 vestingAmount = 10e18;
        uint256 vestingPeriod = 10 days;
        uint256 warpTime = 5 days;

        _depositAsset(address(asset), address(staker), depositAmount);
        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount, vestingPeriod);

        vm.warp(block.timestamp + warpTime);

        vm.expectRevert();
        staker.pool_redeem(address(pool), 100e18 + 1);

        staker.pool_redeem(address(pool), 100e18);
    }

    function test_redeem_callerNotOwner_badApproval() public {
        Staker shareOwner = new Staker();
        Staker notShareOwner = new Staker();

        uint256 depositAmount = 1e18;
        asset.mint(address(shareOwner), depositAmount);

        shareOwner.erc20_approve(address(asset), address(pool), depositAmount);
        shareOwner.pool_deposit(address(pool), depositAmount);

        shareOwner.erc20_approve(address(pool), address(notShareOwner), depositAmount - 1);
        vm.expectRevert();
        notShareOwner.pool_redeem(address(pool), depositAmount, address(shareOwner), address(shareOwner));

        shareOwner.erc20_approve(address(pool), address(notShareOwner), depositAmount);

        assertEq(pool.allowance(address(shareOwner), address(notShareOwner)), depositAmount);

        notShareOwner.pool_redeem(address(pool), depositAmount, address(notShareOwner), address(shareOwner));

        assertEq(pool.allowance(address(shareOwner), address(notShareOwner)), 0);
    }

    function test_redeem_callerNotOwner_infiniteApprovalForCaller() public {
        Staker shareOwner = new Staker();
        Staker notShareOwner = new Staker();

        uint256 depositAmount = 1e18;
        asset.mint(address(shareOwner), depositAmount);

        shareOwner.erc20_approve(address(asset), address(pool), depositAmount);
        shareOwner.pool_deposit(address(pool), depositAmount);

        shareOwner.erc20_approve(address(pool), address(notShareOwner), type(uint256).max);

        assertEq(pool.allowance(address(shareOwner), address(notShareOwner)), type(uint256).max);

        notShareOwner.pool_redeem(address(pool), depositAmount, address(notShareOwner), address(shareOwner));

        // Infinite approval stays infinite.
        assertEq(pool.allowance(address(shareOwner), address(notShareOwner)), type(uint256).max);
    }
}

// contract RedeemRevertOnTransfers is PoolTestBase {
//     MockRevertingERC20 revertingAsset;
//     Staker staker;

//     function setUp() public virtual override {
//         revertingAsset = new MockRevertingERC20("MockToken", "MT", 18, address(123));
//         pool = new RevenueDistributionToken(address(this), address(revertingAsset), 1e30, "TEST POOL", "TEST");
//         staker = new Staker();

//         vm.warp(START); // Warp to non-zero timestamp
//     }

//     function test_redeem_revertOnTransfer(uint256 depositAmount_, uint256 redeemAmount_) public {
//         depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
//         redeemAmount_ = constrictToRange(redeemAmount_, 1, depositAmount_);

//         revertingAsset.mint(address(staker), depositAmount_);

//         staker.erc20_approve(address(revertingAsset), address(pool), depositAmount_);
//         staker.pool_deposit(address(pool), depositAmount_);

//         vm.warp(START + 10 days);

//         address revertingDestination = revertingAsset.revertingDestination();
//         vm.expectRevert();
//         staker.pool_redeem(address(pool), depositAmount_, revertingDestination, address(staker));

//         staker.pool_redeem(address(pool), depositAmount_, address(1), address(staker));
//     }
// }

contract RedeemTests is PoolSuccessTestBase {
    function test_redeem_singleUser_preVesting() public {
        address staker = address(new Staker());

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

        _assertRedeem(staker, 1000, false);
    }

    function testFuzz_redeem_singleUser_preVesting(uint256 depositAmount_, uint256 redeemAmount_) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        redeemAmount_ = constrictToRange(redeemAmount_, 1, depositAmount_);

        address staker = address(new Staker());

        _depositAsset(address(asset), staker, depositAmount_);

        pool_balanceOf_staker_change = -_toInt256(redeemAmount_);
        pool_totalSupply_change = -_toInt256(redeemAmount_);
        pool_freeAssets_change = -_toInt256(redeemAmount_);
        pool_totalAssets_change = -_toInt256(redeemAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 0;

        asset_balanceOf_staker_change = _toInt256(redeemAmount_);
        asset_balanceOf_pool_change = -_toInt256(redeemAmount_);

        _assertRedeem(staker, redeemAmount_, true);
    }

    function test_redeem_singleUser_midVesting() public {
        address staker = address(new Staker());

        _depositAsset(address(asset), staker, 100e18);
        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 200 seconds);

        vm.warp(block.timestamp + 100 seconds); // Vest 5e18 tokens

        pool_balanceOf_staker_change = -20e18;
        pool_totalSupply_change = -20e18;
        pool_freeAssets_change = -16e18; // freeAssets gets updated to reflects 5e18 vested tokens during withdraw (+5 - 21)
        pool_totalAssets_change = -21e18; // 20 * 10.5
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 100 seconds;

        asset_balanceOf_staker_change = 21e18;
        asset_balanceOf_pool_change = -21e18;

        _assertRedeem(staker, 20e18, false);
    }

    function testFuzz_redeem_singleUser_midVesting(
        uint256 depositAmount_,
        uint256 redeemAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        uint256 warpTime_
    ) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        redeemAmount_ = constrictToRange(redeemAmount_, 1, depositAmount_);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 100 days);
        warpTime_ = constrictToRange(warpTime_, 0, vestingPeriod_);

        address staker = address(new Staker());

        _depositAsset(address(asset), staker, depositAmount_);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + warpTime_);

        uint256 expectedWithdrawnFunds = redeemAmount_ * pool.totalAssets() / pool.totalSupply();
        uint256 vestedAmount = pool.issuanceRate() * warpTime_ / 1e30;

        pool_balanceOf_staker_change = -_toInt256(redeemAmount_);
        pool_totalSupply_change = -_toInt256(redeemAmount_);
        pool_totalAssets_change = -_toInt256(expectedWithdrawnFunds);
        pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(expectedWithdrawnFunds); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(warpTime_);

        asset_balanceOf_staker_change = _toInt256(expectedWithdrawnFunds);
        asset_balanceOf_pool_change = -_toInt256(expectedWithdrawnFunds);

        _assertRedeem(staker, redeemAmount_, true);
    }

    function test_redeem_singleUser_postVesting() public {
        address staker = address(new Staker());

        _depositAsset(address(asset), staker, 100e18);
        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 200 seconds);

        vm.warp(START + 201 seconds); // Vest 5e18 tokens

        pool_balanceOf_staker_change = -20e18;
        pool_totalSupply_change = -20e18;
        pool_freeAssets_change = -12e18; // freeAssets gets updated to reflects 10e18 vested tokens during withdraw (+10 - 22)
        pool_totalAssets_change = -22e18; // 20 * 1.1
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -(0.05e18 * 1e30); // Gets set to zero.
        pool_lastUpdated_change = 201 seconds;

        asset_balanceOf_staker_change = 22e18;
        asset_balanceOf_pool_change = -22e18;

        _assertRedeem(staker, 20e18, false);
    }

    function testFuzz_redeem_singleUser_postVesting(
        uint256 depositAmount_,
        uint256 redeemAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_
    ) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);
        redeemAmount_ = constrictToRange(redeemAmount_, 1, depositAmount_);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 100 days);

        address staker = address(new Staker());

        _depositAsset(address(asset), staker, depositAmount_);
        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 1 seconds);

        uint256 expectedWithdrawnFunds = pool.previewRedeem(redeemAmount_);

        pool_balanceOf_staker_change = -_toInt256(redeemAmount_);
        pool_totalSupply_change = -_toInt256(redeemAmount_);
        pool_totalAssets_change = -_toInt256(expectedWithdrawnFunds);
        pool_freeAssets_change = _toInt256(vestingAmount_) - _toInt256(expectedWithdrawnFunds); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate());
        pool_lastUpdated_change = _toInt256(vestingPeriod_ + 1 seconds);

        asset_balanceOf_staker_change = _toInt256(expectedWithdrawnFunds);
        asset_balanceOf_pool_change = -_toInt256(expectedWithdrawnFunds);

        _assertRedeem(staker, redeemAmount_, true);
    }

    function testFuzz_redeem_multiUser_midVesting(
        uint256 iterations_,
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 redeemSeed_,
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
            uint256 redeemAmount = uint256(keccak256(abi.encodePacked(redeemSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            redeemAmount = constrictToRange(redeemAmount, 1, pool.balanceOf(address(stakers[i])));
            warpTime = constrictToRange(warpTime, 0, (vestingPeriod_ - initWarpTime) / iterations_);

            vm.warp(block.timestamp + warpTime);

            uint256 expectedWithdrawnFunds = pool.previewRedeem(redeemAmount);
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            pool_balanceOf_staker_change = -_toInt256(redeemAmount);
            pool_totalSupply_change = -_toInt256(redeemAmount);
            pool_totalAssets_change = -_toInt256(expectedWithdrawnFunds);
            pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(expectedWithdrawnFunds);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_staker_change = _toInt256(expectedWithdrawnFunds);
            asset_balanceOf_pool_change = -_toInt256(expectedWithdrawnFunds);

            _assertRedeem(address(stakers[i]), redeemAmount, true);
        }
    }

    function testFuzz_redeem_multiUser_postVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 redeemSeed_,
        bytes32 warpSeed_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1e6, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1e6, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days, 1e29);

        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 1e18);

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
            uint256 redeemAmount = uint256(keccak256(abi.encodePacked(redeemSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            redeemAmount = constrictToRange(redeemAmount, 1, pool.balanceOf(address(stakers[i])));
            warpTime = constrictToRange(warpTime, 0, (vestingPeriod_ - 12 hours) / 10);

            vm.warp(block.timestamp + warpTime);

            uint256 expectedWithdrawnFunds = pool.previewRedeem(redeemAmount);
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            pool_balanceOf_staker_change = -_toInt256(redeemAmount);
            pool_totalSupply_change = -_toInt256(redeemAmount);
            pool_totalAssets_change = -_toInt256(expectedWithdrawnFunds);
            pool_freeAssets_change = _toInt256(vestedAmount) - _toInt256(expectedWithdrawnFunds); // freeAssets gets updated to reflects 5e18 vested tokens during withdraw
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_staker_change = _toInt256(expectedWithdrawnFunds);
            asset_balanceOf_pool_change = -_toInt256(expectedWithdrawnFunds);

            _assertRedeem(address(stakers[i]), redeemAmount, true);
        }
    }
}
