// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.7;

import {ERC20} from "solady/tokens/ERC20.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockRevertingERC20} from "../mocks/MockRevertingERC20.sol";
import {RevenueDistributionToken} from "src/RevenueDistributionToken.sol";
import {BaseTest} from "../base/BaseTest.sol";
import {PoolTestBase} from "../base/PoolTestBase.sol";
import {PoolSuccessTestBase} from "../base/PoolSuccessTestBase.sol";
import {Staker} from "../accounts/Staker.sol";
// =============================================================
//                       DEPOSIT TESTS
// =============================================================

contract DepositFailureTests is PoolTestBase {
    Staker staker;

    function setUp() public virtual override {
        super.setUp();
        staker = new Staker();
    }

    function test_deposit_zeroReceiver() public {
        asset.mint(address(staker), 1);
        staker.erc20_approve(address(asset), address(pool), 1);

        vm.expectRevert();
        staker.pool_deposit(address(pool), 1, address(0));

        staker.pool_deposit(address(pool), 1, address(staker));
    }

    function test_deposit_zeroAssets() public {
        asset.mint(address(staker), 1);
        staker.erc20_approve(address(asset), address(pool), 1);

        vm.expectRevert();
        staker.pool_deposit(address(pool), 0);

        staker.pool_deposit(address(pool), 1);
    }

    function test_deposit_badApprove(uint256 depositAmount_) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);

        asset.mint(address(staker), depositAmount_);

        staker.erc20_approve(address(asset), address(pool), depositAmount_ - 1);

        vm.expectRevert();
        staker.pool_deposit(address(pool), depositAmount_);

        staker.erc20_approve(address(asset), address(pool), depositAmount_);
        staker.pool_deposit(address(pool), depositAmount_);
    }

    function test_deposit_insufficientBalance(uint256 depositAmount_) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);

        asset.mint(address(staker), depositAmount_);
        staker.erc20_approve(address(asset), address(pool), depositAmount_ + 1);

        vm.expectRevert();
        staker.pool_deposit(address(pool), depositAmount_ + 1);

        staker.erc20_approve(address(asset), address(pool), depositAmount_);
        staker.pool_deposit(address(pool), depositAmount_);
    }

    function test_deposit_zeroShares() public {
        // Do a deposit so that totalSupply is non-zero
        asset.mint(address(this), 20e18);
        asset.approve(address(pool), 20e18);
        pool.deposit(20e18, address(this));

        _transferAndUpdateVesting(address(asset), address(pool), 5e18, 10 seconds);

        vm.warp(block.timestamp + 2 seconds);

        uint256 minDeposit = (pool.totalAssets() - 1) / pool.totalSupply() + 1;

        asset.mint(address(staker), minDeposit);
        staker.erc20_approve(address(asset), address(pool), minDeposit);

        vm.expectRevert();
        staker.pool_deposit(address(pool), minDeposit - 1);

        staker.pool_deposit(address(pool), minDeposit);
    }
}

contract DepositTests is PoolSuccessTestBase {
    function test_deposit_singleUser_preVesting() public {
        uint256 depositAmount = 1000;

        pool_balanceOf_staker_change = 1000;
        pool_totalSupply_change = 1000;
        pool_freeAssets_change = 1000;
        pool_totalAssets_change = 1000;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 10_000_000; // First deposit updates `lastUpdated`

        asset_balanceOf_staker_change = -1000;
        asset_balanceOf_pool_change = 1000;
        asset_allowance_staker_pool_change = -1000;

        address staker = address(new Staker());

        _assertDeposit(staker, depositAmount, false);
    }

    function testFuzz_deposit_singleUser_preVesting(uint256 depositAmount_) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);

        pool_balanceOf_staker_change = _toInt256(depositAmount_);
        pool_totalSupply_change = _toInt256(depositAmount_);
        pool_freeAssets_change = _toInt256(depositAmount_);
        pool_totalAssets_change = _toInt256(depositAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(START); // First deposit updates `lastUpdated`

        asset_balanceOf_staker_change = -_toInt256(depositAmount_);
        asset_balanceOf_pool_change = _toInt256(depositAmount_);
        asset_allowance_staker_pool_change = -_toInt256(depositAmount_);

        address staker = address(new Staker());

        _assertDeposit(staker, depositAmount_, false);
    }

    function test_deposit_singleUser_midVesting() public {
        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero.
        _depositAsset(address(asset), address(setupStaker), 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 10 seconds);

        vm.warp(START + 5 seconds); // Vest 5e18 tokens.

        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.25e18); // 1 * (20 + 5) / 20

        uint256 depositAmount = 10e18;

        pool_balanceOf_staker_change = 8e18; // 10e18 / 1.25
        pool_totalSupply_change = 8e18;
        pool_freeAssets_change = 15e18; // Captures vested amount (5 + 10)
        pool_totalAssets_change = 10e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 5 seconds;

        asset_balanceOf_staker_change = -10e18;
        asset_balanceOf_pool_change = 10e18;
        asset_allowance_staker_pool_change = -10e18;

        address staker = address(new Staker());

        _assertDeposit(staker, depositAmount, false);
    }

    function testFuzz_deposit_singleUser_midVesting(
        uint256 initialAmount_,
        uint256 depositAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        uint256 warpTime_
    ) public {
        Staker setupStaker = new Staker();

        initialAmount_ = constrictToRange(initialAmount_, 1, 1e6); // Kept smaller since its just needed to increase totalSupply
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 365 days);
        warpTime_ = constrictToRange(vestingPeriod_, 0, vestingPeriod_);

        // Do a deposit so that totalSupply is non-zero.
        _depositAsset(address(asset), address(setupStaker), initialAmount_);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + warpTime_);

        // Get minimum deposit to avoid ZERO_SHARES.
        uint256 minDeposit = _getMinDeposit(address(pool));
        depositAmount_ = constrictToRange(depositAmount_, minDeposit, 1e29 + 1);

        uint256 expectedShares = depositAmount_ * pool.totalSupply() / pool.totalAssets();
        uint256 vestedAmount = pool.issuanceRate() * warpTime_ / 1e30;

        pool_balanceOf_staker_change = _toInt256(expectedShares);
        pool_totalSupply_change = _toInt256(expectedShares);
        pool_freeAssets_change = _toInt256(vestedAmount + depositAmount_); // Captures vested amount
        pool_totalAssets_change = _toInt256(depositAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(warpTime_);

        asset_balanceOf_staker_change = -_toInt256(depositAmount_);
        asset_balanceOf_pool_change = _toInt256(depositAmount_);
        asset_allowance_staker_pool_change = -_toInt256(depositAmount_);

        address staker = address(new Staker());

        _assertDeposit(staker, depositAmount_, true);
    }

    function test_deposit_singleUser_postVesting() public {
        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), 5e18, 10 seconds); // Vest full 5e18 tokens

        vm.warp(START + 11 seconds); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.25e18); // 1 * (20 + 5) / 20

        pool_balanceOf_staker_change = 8e18; // 10e18 / 1.25
        pool_totalSupply_change = 8e18;
        pool_freeAssets_change = 15e18; // Captures vested amount
        pool_totalAssets_change = 10e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate()); // Gets set to zero
        pool_lastUpdated_change = 11 seconds;

        asset_balanceOf_staker_change = -10e18;
        asset_balanceOf_pool_change = 10e18;
        asset_allowance_staker_pool_change = -10e18;

        address staker = address(new Staker());

        _assertDeposit(staker, 10e18, false);
    }

    function testFuzz_deposit_singleUser_postVesting(
        uint256 initialAmount_,
        uint256 depositAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_
    ) public {
        Staker setupStaker = new Staker();

        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 10_000 days);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 1); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        // Get minimum deposit to avoid ZERO_SHARES.
        uint256 minDeposit = _getMinDeposit(address(pool));
        depositAmount_ = constrictToRange(depositAmount_, minDeposit, 1e29 + 1);

        uint256 expectedShares = depositAmount_ * pool.totalSupply() / pool.totalAssets();

        pool_balanceOf_staker_change = _toInt256(expectedShares);
        pool_totalSupply_change = _toInt256(expectedShares);
        pool_freeAssets_change = _toInt256(vestingAmount_ + depositAmount_); // Captures vested amount
        pool_totalAssets_change = _toInt256(depositAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate()); // Gets set to zero
        pool_lastUpdated_change = _toInt256(vestingPeriod_ + 1);

        asset_balanceOf_staker_change = -_toInt256(depositAmount_);
        asset_balanceOf_pool_change = _toInt256(depositAmount_);
        asset_allowance_staker_pool_change = -_toInt256(depositAmount_);

        address staker = address(new Staker());

        _assertDeposit(staker, depositAmount_, true);
    }

    function testFuzz_deposit_multiUser_midVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 warpSeed_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days, 365 days);

        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        for (uint256 i = 1; i < 11; ++i) {
            uint256 depositAmount = uint256(keccak256(abi.encodePacked(depositSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            // Get minimum deposit to avoid ZERO_SHARES.
            uint256 minDeposit = _getMinDeposit(address(pool));
            depositAmount = constrictToRange(depositAmount, minDeposit, 1e29 + 1); // + 1 since we round up in min deposit.
            warpTime = constrictToRange(warpTime, 0, vestingPeriod_ / 10); // Needs to be smaller than vestingPeriod_ / 10

            vm.warp(block.timestamp + warpTime);

            uint256 expectedShares = depositAmount * pool.totalSupply() / pool.totalAssets();
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            pool_balanceOf_staker_change = _toInt256(expectedShares);
            pool_totalSupply_change = _toInt256(expectedShares);
            pool_freeAssets_change = _toInt256(vestedAmount + depositAmount); // Captures vested amount
            pool_totalAssets_change = _toInt256(depositAmount);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_staker_change = -_toInt256(depositAmount);
            asset_balanceOf_pool_change = _toInt256(depositAmount);
            asset_allowance_staker_pool_change = -_toInt256(depositAmount);

            address staker = address(new Staker());

            _assertDeposit(staker, depositAmount, true);
        }
    }

    function testFuzz_deposit_multiUser_postVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 seed_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1, 365 days);

        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 1); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        // Do another deposit to set all params to be uniform
        _depositAsset(address(asset), address(setupStaker), 1e18);

        for (uint256 i = 1; i < 11; ++i) {
            uint256 depositAmount = uint256(keccak256(abi.encodePacked(seed_, i)));

            // Get minimum deposit to avoid ZERO_SHARES.
            uint256 minDeposit = _getMinDeposit(address(pool));
            depositAmount = constrictToRange(depositAmount, minDeposit, 1e29 + 1); // + 1 since we round up in min deposit.

            uint256 expectedShares = depositAmount * pool.totalSupply() / pool.totalAssets();

            pool_balanceOf_staker_change = _toInt256(expectedShares);
            pool_totalSupply_change = _toInt256(expectedShares);
            pool_freeAssets_change = _toInt256(depositAmount); // Captures vested amount
            pool_totalAssets_change = _toInt256(depositAmount);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = 0;

            asset_balanceOf_staker_change = -_toInt256(depositAmount);
            asset_balanceOf_pool_change = _toInt256(depositAmount);
            asset_allowance_staker_pool_change = -_toInt256(depositAmount);

            address staker = address(new Staker());

            _assertDeposit(staker, depositAmount, true);
        }
    }
}

contract DepositWithPermitFailureTests is PoolTestBase {
    address staker;
    address notStaker;

    uint256 stakerPrivateKey = 1;
    uint256 notStakerPrivateKey = 2;

    function setUp() public override {
        super.setUp();

        staker = vm.addr(stakerPrivateKey);
        notStaker = vm.addr(notStakerPrivateKey);
    }

    function test_depositWithPermit_zeroAddress() public {
        uint256 depositAmount = 1e18;
        asset.mint(address(staker), depositAmount);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker, address(pool), depositAmount, deadline, stakerPrivateKey);

        vm.startPrank(staker);

        vm.expectRevert();
        pool.depositWithPermit(depositAmount, staker, deadline, 17, r, s);

        pool.depositWithPermit(depositAmount, staker, deadline, v, r, s);
    }

    function test_depositWithPermit_notStakerSignature() public {
        uint256 depositAmount = 1e18;
        asset.mint(address(staker), depositAmount);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(notStaker, address(pool), depositAmount, deadline, notStakerPrivateKey);

        vm.startPrank(staker);

        vm.expectRevert();
        pool.depositWithPermit(depositAmount, staker, deadline, v, r, s);

        (v, r, s) = _getValidPermitSignature(staker, address(pool), depositAmount, deadline, stakerPrivateKey);

        pool.depositWithPermit(depositAmount, staker, deadline, v, r, s);
    }

    function test_depositWithPermit_pastDeadline() public {
        uint256 depositAmount = 1e18;
        asset.mint(address(staker), depositAmount);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker, address(pool), depositAmount, deadline, stakerPrivateKey);

        vm.startPrank(staker);

        vm.warp(deadline + 1);

        vm.expectRevert();
        pool.depositWithPermit(depositAmount, staker, deadline, v, r, s);

        vm.warp(deadline);

        pool.depositWithPermit(depositAmount, staker, deadline, v, r, s);
    }

    function test_depositWithPermit_replay() public {
        uint256 depositAmount = 1e18;
        asset.mint(address(staker), depositAmount * 2);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker, address(pool), depositAmount, deadline, stakerPrivateKey);

        vm.startPrank(staker);

        pool.depositWithPermit(depositAmount, staker, deadline, v, r, s);

        vm.expectRevert();
        pool.depositWithPermit(depositAmount, staker, deadline, v, r, s);
    }
}

contract DepositWithPermitTests is PoolSuccessTestBase {
    function test_depositWithPermit_singleUser_preVesting() public {
        uint256 depositAmount = 1000;

        pool_balanceOf_staker_change = 1000;
        pool_totalSupply_change = 1000;
        pool_freeAssets_change = 1000;
        pool_totalAssets_change = 1000;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 10_000_000; // First deposit updates `lastUpdated`

        asset_balanceOf_staker_change = -1000;
        asset_balanceOf_pool_change = 1000;
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertDepositWithPermit(staker, 1, depositAmount, false);
    }

    function testFuzz_depositWithPermit_singleUser_preVesting(uint256 depositAmount_) public {
        depositAmount_ = constrictToRange(depositAmount_, 1, 1e29);

        pool_balanceOf_staker_change = _toInt256(depositAmount_);
        pool_totalSupply_change = _toInt256(depositAmount_);
        pool_freeAssets_change = _toInt256(depositAmount_);
        pool_totalAssets_change = _toInt256(depositAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(START); // First deposit updates `lastUpdated`

        asset_balanceOf_staker_change = -_toInt256(depositAmount_);
        asset_balanceOf_pool_change = _toInt256(depositAmount_);
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertDepositWithPermit(staker, 1, depositAmount_, false);
    }

    function test_depositWithPermit_singleUser_midVesting() public {
        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 10 seconds); // Vest full 5e18 tokens

        vm.warp(START + 5 seconds);

        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.25e18); // 1 * (20 + 5) / 20

        uint256 depositAmount = 10e18;

        pool_balanceOf_staker_change = 8e18; // 10e18 / 1.25
        pool_totalSupply_change = 8e18;
        pool_freeAssets_change = 15e18; // Captures vested amount
        pool_totalAssets_change = 10e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 5 seconds;

        asset_balanceOf_staker_change = -10e18;
        asset_balanceOf_pool_change = 10e18;
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertDepositWithPermit(staker, 1, depositAmount, true);
    }

    function testFuzz_depositWithPermit_singleUser_midVesting(
        uint256 initialAmount_,
        uint256 depositAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        uint256 warpTime_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e6); // Kept smaller since its just needed to increase totalSupply
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 365 days);
        warpTime_ = constrictToRange(warpTime_, 1 seconds, vestingPeriod_);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, initialAmount_);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + warpTime_);

        // Get minimum deposit to avoid ZERO_SHARES.
        uint256 minDeposit = _getMinDeposit(address(pool));
        depositAmount_ = constrictToRange(depositAmount_, minDeposit, 1e29 + 1);

        uint256 expectedShares = depositAmount_ * pool.totalSupply() / pool.totalAssets();
        uint256 vestedAmount = pool.issuanceRate() * warpTime_ / 1e30;

        pool_balanceOf_staker_change = _toInt256(expectedShares);
        pool_totalSupply_change = _toInt256(expectedShares);
        pool_freeAssets_change = _toInt256(vestedAmount + depositAmount_); // Captures vested amount
        pool_totalAssets_change = _toInt256(depositAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(warpTime_);

        asset_balanceOf_staker_change = -_toInt256(depositAmount_);
        asset_balanceOf_pool_change = _toInt256(depositAmount_);
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertDepositWithPermit(staker, 1, depositAmount_, true);
    }

    function test_depositWithPermit_singleUser_postVesting() public {
        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), 5e18, 10 seconds); // Vest full 5e18 tokens

        vm.warp(START + 11 seconds); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.25e18); // 1 * (20 + 5) / 20

        pool_balanceOf_staker_change = 8e18; // 10e18 / 1.25
        pool_totalSupply_change = 8e18;
        pool_freeAssets_change = 15e18; // Captures vested amount
        pool_totalAssets_change = 10e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate()); // Gets set to zero
        pool_lastUpdated_change = 11 seconds;

        asset_balanceOf_staker_change = -10e18;
        asset_balanceOf_pool_change = 10e18;
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertDepositWithPermit(staker, 1, 10e18, false);
    }

    function testFuzz_depositWithPermit_singleUser_postVesting(
        uint256 initialAmount_,
        uint256 depositAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 10_000 days);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 1); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        // Get minimum deposit to avoid ZERO_SHARES.
        uint256 minDeposit = _getMinDeposit(address(pool));
        depositAmount_ = constrictToRange(depositAmount_, minDeposit, 1e29 + 1);

        uint256 expectedShares = depositAmount_ * pool.totalSupply() / pool.totalAssets();

        pool_balanceOf_staker_change = _toInt256(expectedShares);
        pool_totalSupply_change = _toInt256(expectedShares);
        pool_freeAssets_change = _toInt256(vestingAmount_ + depositAmount_); // Captures vested amount
        pool_totalAssets_change = _toInt256(depositAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate()); // Gets set to zero
        pool_lastUpdated_change = _toInt256(vestingPeriod_ + 1);

        asset_balanceOf_staker_change = -_toInt256(depositAmount_);
        asset_balanceOf_pool_change = _toInt256(depositAmount_);
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertDepositWithPermit(staker, 1, depositAmount_, true);
    }

    function testFuzz_depositWithPermit_multiUser_midVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 depositSeed_,
        bytes32 warpSeed_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days, 365 days);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        for (uint256 i = 1; i < 11; ++i) {
            uint256 depositAmount = uint256(keccak256(abi.encodePacked(depositSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            // Get minimum deposit to avoid ZERO_SHARES.
            uint256 minDeposit = _getMinDeposit(address(pool));
            depositAmount = constrictToRange(depositAmount, minDeposit, 1e29 + 1); // + 1 since we round up in min deposit.
            warpTime = constrictToRange(warpTime, 0, vestingPeriod_ / 10); // Needs to be smaller than vestingPeriod_ / 10

            vm.warp(block.timestamp + warpTime);

            uint256 expectedShares = depositAmount * pool.totalSupply() / pool.totalAssets();
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            pool_balanceOf_staker_change = _toInt256(expectedShares);
            pool_totalSupply_change = _toInt256(expectedShares);
            pool_freeAssets_change = _toInt256(vestedAmount + depositAmount); // Captures vested amount
            pool_totalAssets_change = _toInt256(depositAmount);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_staker_change = -_toInt256(depositAmount);
            asset_balanceOf_pool_change = _toInt256(depositAmount);
            asset_nonces_change = 1;
            asset_allowance_staker_pool_change = 0;

            address staker = vm.addr(i);

            _assertDepositWithPermit(staker, i, depositAmount, true);
        }
    }

    function testFuzz_depositWithPermit_multiUser_postVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 seed_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1, 365 days);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + vestingPeriod_ + 1); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        // Do another deposit to set all params to be uniform
        _depositAsset(address(asset), TESTER, 1e18);

        for (uint256 i = 1; i < 11; ++i) {
            uint256 depositAmount = uint256(keccak256(abi.encodePacked(seed_, i)));

            // Get minimum deposit to avoid ZERO_SHARES.
            uint256 minDeposit = _getMinDeposit(address(pool));
            depositAmount = constrictToRange(depositAmount, minDeposit, 1e29 + 1); // + 1 since we round up in min deposit.

            uint256 expectedShares = depositAmount * pool.totalSupply() / pool.totalAssets();

            pool_balanceOf_staker_change = _toInt256(expectedShares);
            pool_totalSupply_change = _toInt256(expectedShares);
            pool_freeAssets_change = _toInt256(depositAmount); // Captures vested amount
            pool_totalAssets_change = _toInt256(depositAmount);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = 0;

            asset_balanceOf_staker_change = -_toInt256(depositAmount);
            asset_balanceOf_pool_change = _toInt256(depositAmount);
            asset_nonces_change = 1;
            asset_allowance_staker_pool_change = 0;

            address staker = vm.addr(i);

            _assertDepositWithPermit(staker, i, depositAmount, true);
        }
    }
}
