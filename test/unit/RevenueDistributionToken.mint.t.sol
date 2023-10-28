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
//                       MINT TESTS
// =============================================================

contract MintFailureTests is PoolTestBase {
    address staker = vm.addr(1);

    function setUp() public virtual override {
        super.setUp();
    }

    function test_mint_zeroReceiver() public {
        asset.mint(address(staker), 1);

        vm.startPrank(staker);
        asset.approve(address(pool), 1);

        vm.expectRevert();
        pool.mint(1, address(0));

        pool.mint(1, address(staker));
    }

    function test_mint_zeroAmount() public {
        asset.mint(address(staker), 1);

        vm.startPrank(staker);
        asset.approve(address(pool), 1);

        vm.expectRevert();
        pool.mint(0, staker);

        pool.mint(1, staker);
    }

    function test_mint_badApprove(uint256 mintAmount_) public {
        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);

        uint256 depositAmount = pool.previewMint(mintAmount_);

        asset.mint(address(staker), depositAmount);

        vm.startPrank(staker);
        asset.approve(address(pool), depositAmount - 1);

        vm.expectRevert();
        pool.mint(mintAmount_, staker);

        asset.approve(address(pool), depositAmount);
        pool.mint(mintAmount_, staker);
    }

    function test_mint_insufficientBalance(uint256 mintAmount_) public {
        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);

        uint256 depositAmount = pool.previewMint(mintAmount_);

        vm.startPrank(staker);
        asset.approve(address(pool), depositAmount);

        vm.expectRevert();
        pool.mint(mintAmount_, staker);

        vm.stopPrank();
        asset.mint(staker, depositAmount);

        vm.startPrank(staker);
        pool.mint(mintAmount_, staker);
    }
}

contract MintTests is PoolSuccessTestBase {
    function test_mint_singleUser_preVesting() public {
        uint256 mintAmount = 1000;

        pool_balanceOf_staker_change = 1000;
        pool_totalSupply_change = 1000;
        pool_freeAssets_change = 1000;
        pool_totalAssets_change = 1000;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(START); // First deposit updates `lastUpdated`

        asset_balanceOf_staker_change = -1000;
        asset_balanceOf_pool_change = 1000;
        asset_allowance_staker_pool_change = -1000;

        address staker = vm.addr(1);

        _assertMint(staker, mintAmount, false);
    }

    function testFuzz_mint_singleUser_preVesting(uint256 mintAmount_) public {
        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);

        pool_balanceOf_staker_change = _toInt256(mintAmount_);
        pool_totalSupply_change = _toInt256(mintAmount_);
        pool_freeAssets_change = _toInt256(mintAmount_);
        pool_totalAssets_change = _toInt256(mintAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(START); // First deposit updates `lastUpdated`

        asset_balanceOf_staker_change = -_toInt256(mintAmount_);
        asset_balanceOf_pool_change = _toInt256(mintAmount_);
        asset_allowance_staker_pool_change = -_toInt256(pool.convertToAssets(mintAmount_));

        address staker = vm.addr(1);

        _assertMint(staker, mintAmount_, false);
    }

    function test_mint_singleUser_midVesting() public {
        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 10 seconds);

        vm.warp(START + 5 seconds);

        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.25e18); // 1 * (20 + 5) / 20

        uint256 mintAmount = 10e18;

        pool_balanceOf_staker_change = 10e18;
        pool_totalSupply_change = 10e18;
        pool_freeAssets_change = 17.5e18; // Captures vested amount
        pool_totalAssets_change = 12.5e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 5 seconds;

        asset_balanceOf_staker_change = -12.5e18;
        asset_balanceOf_pool_change = 12.5e18;
        asset_allowance_staker_pool_change = -12.5e18;

        address staker = vm.addr(1);

        _assertMint(staker, mintAmount, false);
    }

    function testFuzz_mint_singleUser_midVesting(
        uint256 initialAmount_,
        uint256 mintAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        uint256 warpTime_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e6); // Kept smaller since its just needed to increase totalSupply
        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 365 days);
        warpTime_ = constrictToRange(warpTime_, 1 seconds, vestingPeriod_);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, initialAmount_);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + warpTime_);

        uint256 expectedAssets = mintAmount_ * pool.totalAssets() / pool.totalSupply();
        uint256 vestedAmount = pool.issuanceRate() * warpTime_ / 1e30;

        pool_balanceOf_staker_change = _toInt256(mintAmount_);
        pool_totalSupply_change = _toInt256(mintAmount_);
        pool_freeAssets_change = _toInt256(vestedAmount + expectedAssets); // Captures vested amount
        pool_totalAssets_change = _toInt256(expectedAssets);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(warpTime_);

        asset_balanceOf_staker_change = -_toInt256(expectedAssets);
        asset_balanceOf_pool_change = _toInt256(expectedAssets);
        asset_allowance_staker_pool_change = -_toInt256(expectedAssets);

        address staker = vm.addr(1);

        _assertMint(staker, mintAmount_, true);
    }

    function test_mint_singleUser_postVesting() public {
        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), 5e18, 10 seconds); // Vest full 5e18 tokens

        vm.warp(START + 11 seconds); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.25e18); // 1 * (20 + 5) / 20

        uint256 mintAmount = 10e18;

        pool_balanceOf_staker_change = 10e18; // 10e18 / 1.25
        pool_totalSupply_change = 10e18;
        pool_freeAssets_change = 17.5e18; // Captures vested amount
        pool_totalAssets_change = 12.5e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate()); // Gets set to zero
        pool_lastUpdated_change = 11 seconds;

        asset_balanceOf_staker_change = -12.5e18;
        asset_balanceOf_pool_change = 12.5e18;
        asset_allowance_staker_pool_change = -12.5e18;

        address staker = vm.addr(1);

        _assertMint(staker, mintAmount, false);
    }

    function testFuzz_mint_singleUser_postVesting(uint256 initialAmount_, uint256 mintAmount_, uint256 vestingAmount_)
        public
    {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, 10 seconds);

        vm.warp(START + 11 seconds); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        uint256 expectedAssets = mintAmount_ * pool.totalAssets() / pool.totalSupply();

        pool_balanceOf_staker_change = _toInt256(mintAmount_);
        pool_totalSupply_change = _toInt256(mintAmount_);
        pool_freeAssets_change = _toInt256(vestingAmount_ + expectedAssets); // Captures vested amount
        pool_totalAssets_change = _toInt256(expectedAssets);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate()); // Gets set to zero
        pool_lastUpdated_change = 11 seconds;

        asset_balanceOf_staker_change = -_toInt256(expectedAssets);
        asset_balanceOf_pool_change = _toInt256(expectedAssets);
        asset_allowance_staker_pool_change = -_toInt256(expectedAssets);

        address staker = vm.addr(1);

        _assertMint(staker, mintAmount_, true);
    }

    function testFuzz_mint_multiUser_midVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 mintSeed_,
        bytes32 warpSeed_
    ) public {
        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 days, 365 days);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), TESTER, 1e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        for (uint256 i = 1; i < 11; ++i) {
            uint256 mintAmount = uint256(keccak256(abi.encodePacked(mintSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            mintAmount = constrictToRange(mintAmount, 1, 1e29);
            warpTime = constrictToRange(warpTime, 0, vestingPeriod_ / 10); // Needs to be smaller than vestingPeriod_ so we can warp during for loop

            vm.warp(block.timestamp + warpTime);

            uint256 expectedAssets = mintAmount * pool.totalAssets() / pool.totalSupply();
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            pool_balanceOf_staker_change = _toInt256(mintAmount);
            pool_totalSupply_change = _toInt256(mintAmount);
            pool_freeAssets_change = _toInt256(vestedAmount + expectedAssets); // Captures vested amount
            pool_totalAssets_change = _toInt256(expectedAssets);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_staker_change = -_toInt256(expectedAssets);
            asset_balanceOf_pool_change = _toInt256(expectedAssets);
            asset_allowance_staker_pool_change = -_toInt256(expectedAssets);

            address staker = vm.addr(1);

            _assertMint(staker, mintAmount, true);
        }
    }

    function testFuzz_mint_multiUser_postVesting(
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
            uint256 mintAmount = uint256(keccak256(abi.encodePacked(seed_, i)));

            mintAmount = constrictToRange(mintAmount, 1, 1e29);

            uint256 expectedAssets = mintAmount * pool.totalAssets() / pool.totalSupply();

            pool_balanceOf_staker_change = _toInt256(mintAmount);
            pool_totalSupply_change = _toInt256(mintAmount);
            pool_freeAssets_change = _toInt256(expectedAssets); // Captures vested amount
            pool_totalAssets_change = _toInt256(expectedAssets);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = 0;

            asset_balanceOf_staker_change = -_toInt256(expectedAssets);
            asset_balanceOf_pool_change = _toInt256(expectedAssets);
            asset_allowance_staker_pool_change = -_toInt256(expectedAssets);

            address staker = vm.addr(1);

            _assertMint(staker, mintAmount, true);
        }
    }
}

contract MintWithPermitFailureTests is PoolTestBase {
    address staker;
    address notStaker;

    uint256 stakerPrivateKey = 1;
    uint256 notStakerPrivateKey = 2;

    function setUp() public virtual override {
        super.setUp();

        staker = vm.addr(stakerPrivateKey);
        notStaker = vm.addr(notStakerPrivateKey);
    }

    function test_mintWithPermit_zeroAddress() public {
        uint256 mintAmount = 1e18;
        uint256 maxAssets = pool.previewMint(mintAmount);

        asset.mint(address(staker), maxAssets);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker, address(pool), maxAssets, deadline, stakerPrivateKey);

        vm.startPrank(staker);

        vm.expectRevert();
        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, 17, r, s);

        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, v, r, s);
    }

    function test_mintWithPermit_notStakerSignature() public {
        uint256 mintAmount = 1e18;
        uint256 maxAssets = pool.previewMint(mintAmount);

        asset.mint(address(staker), maxAssets);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(notStaker, address(pool), maxAssets, deadline, notStakerPrivateKey);

        vm.startPrank(staker);

        vm.expectRevert();
        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, v, r, s);

        (v, r, s) = _getValidPermitSignature(staker, address(pool), maxAssets, deadline, stakerPrivateKey);

        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, v, r, s);
    }

    function test_mintWithPermit_pastDeadline() public {
        uint256 mintAmount = 1e18;
        uint256 maxAssets = pool.previewMint(mintAmount);

        asset.mint(address(staker), maxAssets);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker, address(pool), maxAssets, deadline, stakerPrivateKey);

        vm.startPrank(staker);

        vm.warp(deadline + 1);

        vm.expectRevert();
        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, v, r, s);

        vm.warp(deadline);

        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, v, r, s);
    }

    function test_mintWithPermit_insufficientPermit() public {
        uint256 mintAmount = 1e18;
        uint256 maxAssets = pool.previewMint(mintAmount);

        asset.mint(address(staker), maxAssets);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker, address(pool), maxAssets - 1, deadline, stakerPrivateKey);

        vm.startPrank(staker);

        vm.expectRevert();
        pool.mintWithPermit(mintAmount, staker, maxAssets - 1, deadline, v, r, s);

        (v, r, s) = _getValidPermitSignature(staker, address(pool), maxAssets, deadline, stakerPrivateKey);

        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, v, r, s);
    }

    function test_mintWithPermit_replay() public {
        uint256 mintAmount = 1e18;
        uint256 maxAssets = pool.previewMint(mintAmount);

        asset.mint(address(staker), maxAssets * 2);

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker, address(pool), maxAssets, deadline, stakerPrivateKey);

        vm.startPrank(staker);

        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, v, r, s);

        vm.expectRevert();
        pool.mintWithPermit(mintAmount, staker, maxAssets, deadline, v, r, s);
    }
}

contract MintWithPermitTests is PoolSuccessTestBase {
    function test_mintWithPermit_singleUser_preVesting() public {
        uint256 mintAmount = 1000;

        pool_balanceOf_staker_change = 1000;
        pool_totalSupply_change = 1000;
        pool_freeAssets_change = 1000;
        pool_totalAssets_change = 1000;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(START); // First deposit updates `lastUpdated`

        asset_balanceOf_staker_change = -1000;
        asset_balanceOf_pool_change = 1000;
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertMintWithPermit(staker, 1, mintAmount, false);
    }

    function testFuzz_mintWithPermit_singleUser_preVesting(uint256 mintAmount_) public {
        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);

        pool_balanceOf_staker_change = _toInt256(mintAmount_);
        pool_totalSupply_change = _toInt256(mintAmount_);
        pool_freeAssets_change = _toInt256(mintAmount_);
        pool_totalAssets_change = _toInt256(mintAmount_);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(START); // First deposit updates `lastUpdated`

        asset_balanceOf_staker_change = -_toInt256(mintAmount_);
        asset_balanceOf_pool_change = _toInt256(mintAmount_);
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertMintWithPermit(staker, 1, mintAmount_, false);
    }

    function test_mintWithPermit_singleUser_midVesting() public {
        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), 10e18, 10 seconds); // Vest full 5e18 tokens

        vm.warp(START + 5 seconds); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.25e18); // 1 * (20 + 5) / 20

        pool_balanceOf_staker_change = 10e18;
        pool_totalSupply_change = 10e18;
        pool_freeAssets_change = 17.5e18; // Captures vested amount
        pool_totalAssets_change = 12.5e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = 5 seconds;

        asset_balanceOf_staker_change = -12.5e18;
        asset_balanceOf_pool_change = 12.5e18;
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertMintWithPermit(staker, 1, 10e18, false);
    }

    function testFuzz_mintWithPermit_singleUser_midVesting(
        uint256 initialAmount_,
        uint256 mintAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        uint256 warpTime_
    ) public {
        Staker setupStaker = new Staker();

        initialAmount_ = constrictToRange(initialAmount_, 1, 1e6); // Kept smaller since its just needed to increase totalSupply
        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);
        vestingPeriod_ = constrictToRange(vestingPeriod_, 1 seconds, 365 days);
        warpTime_ = constrictToRange(warpTime_, 1 seconds, vestingPeriod_);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), initialAmount_);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, vestingPeriod_);

        vm.warp(START + warpTime_); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        uint256 expectedAssets = mintAmount_ * pool.totalAssets() / pool.totalSupply();
        uint256 vestedAmount = pool.issuanceRate() * warpTime_ / 1e30;

        pool_balanceOf_staker_change = _toInt256(mintAmount_);
        pool_totalSupply_change = _toInt256(mintAmount_);
        pool_freeAssets_change = _toInt256(vestedAmount + expectedAssets); // Captures vested amount
        pool_totalAssets_change = _toInt256(expectedAssets);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = 0;
        pool_lastUpdated_change = _toInt256(warpTime_);

        asset_balanceOf_staker_change = -_toInt256(expectedAssets);
        asset_balanceOf_pool_change = _toInt256(expectedAssets);
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertMintWithPermit(staker, 1, mintAmount_, true);
    }

    function test_mintWithPermit_singleUser_postVesting() public {
        Staker setupStaker = new Staker();

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), 5e18, 10 seconds); // Vest full 5e18 tokens

        vm.warp(START + 11 seconds); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        assertEq(pool.convertToAssets(sampleSharesToConvert), 1.25e18); // 1 * (20 + 5) / 20

        uint256 mintAmount = 10e18;

        pool_balanceOf_staker_change = 10e18; // 10e18 / 1.25
        pool_totalSupply_change = 10e18;
        pool_freeAssets_change = 17.5e18; // Captures vested amount
        pool_totalAssets_change = 12.5e18;
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate()); // Gets set to zero
        pool_lastUpdated_change = 11 seconds;

        asset_balanceOf_staker_change = -12.5e18;
        asset_balanceOf_pool_change = 12.5e18;
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertMintWithPermit(staker, 1, mintAmount, false);
    }

    function testFuzz_mintWithPermit_singleUser_postVesting(
        uint256 initialAmount_,
        uint256 mintAmount_,
        uint256 vestingAmount_
    ) public {
        Staker setupStaker = new Staker();

        initialAmount_ = constrictToRange(initialAmount_, 1, 1e29);
        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);
        vestingAmount_ = constrictToRange(vestingAmount_, 1, 1e29);

        // Do a deposit so that totalSupply is non-zero
        _depositAsset(address(asset), address(setupStaker), 20e18);

        _transferAndUpdateVesting(address(asset), address(pool), vestingAmount_, 10 seconds);

        vm.warp(START + 11 seconds); // To demonstrate `lastUpdated` and `issuanceRate` change, as well as vesting

        mintAmount_ = constrictToRange(mintAmount_, 1, 1e29);

        uint256 expectedAssets = mintAmount_ * pool.totalAssets() / pool.totalSupply();

        pool_balanceOf_staker_change = _toInt256(mintAmount_);
        pool_totalSupply_change = _toInt256(mintAmount_);
        pool_freeAssets_change = _toInt256(vestingAmount_ + expectedAssets); // Captures vested amount
        pool_totalAssets_change = _toInt256(expectedAssets);
        pool_convertToAssets_change = 0;
        pool_convertToShares_change = 0;
        pool_issuanceRate_change = -_toInt256(pool.issuanceRate()); // Gets set to zero
        pool_lastUpdated_change = 11 seconds;

        asset_balanceOf_staker_change = -_toInt256(expectedAssets);
        asset_balanceOf_pool_change = _toInt256(expectedAssets);
        asset_nonces_change = 1;
        asset_allowance_staker_pool_change = 0;

        address staker = vm.addr(1);

        _assertMintWithPermit(staker, 1, mintAmount_, true);
    }

    function testFuzz_mintWithPermit_multiUser_midVesting(
        uint256 initialAmount_,
        uint256 vestingAmount_,
        uint256 vestingPeriod_,
        bytes32 mintSeed_,
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
            uint256 mintAmount = uint256(keccak256(abi.encodePacked(mintSeed_, i)));
            uint256 warpTime = uint256(keccak256(abi.encodePacked(warpSeed_, i)));

            mintAmount = constrictToRange(mintAmount, 1, 1e29);
            warpTime = constrictToRange(warpTime, 0, vestingPeriod_ / 10); // Needs to be smaller than vestingPeriod_ so we can warp during for loop

            vm.warp(block.timestamp + warpTime);

            uint256 expectedAssets = mintAmount * pool.totalAssets() / pool.totalSupply();
            uint256 vestedAmount = pool.issuanceRate() * warpTime / 1e30;

            pool_balanceOf_staker_change = _toInt256(mintAmount);
            pool_totalSupply_change = _toInt256(mintAmount);
            pool_freeAssets_change = _toInt256(vestedAmount + expectedAssets); // Captures vested amount
            pool_totalAssets_change = _toInt256(expectedAssets);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = _toInt256(warpTime);

            asset_balanceOf_staker_change = -_toInt256(expectedAssets);
            asset_balanceOf_pool_change = _toInt256(expectedAssets);
            asset_nonces_change = 1;
            asset_allowance_staker_pool_change = 0;

            address staker = vm.addr(i);

            _assertMintWithPermit(staker, i, mintAmount, true);
        }
    }

    function testFuzz_mintWithPermit_multiUser_postVesting(
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
            uint256 mintAmount = uint256(keccak256(abi.encodePacked(seed_, i)));

            mintAmount = constrictToRange(mintAmount, 1, 1e29);

            uint256 expectedAssets = mintAmount * pool.totalAssets() / pool.totalSupply();

            pool_balanceOf_staker_change = _toInt256(mintAmount);
            pool_totalSupply_change = _toInt256(mintAmount);
            pool_freeAssets_change = _toInt256(expectedAssets); // Captures vested amount
            pool_totalAssets_change = _toInt256(expectedAssets);
            pool_convertToAssets_change = 0;
            pool_convertToShares_change = 0;
            pool_issuanceRate_change = 0;
            pool_lastUpdated_change = 0;

            asset_balanceOf_staker_change = -_toInt256(expectedAssets);
            asset_balanceOf_pool_change = _toInt256(expectedAssets);
            asset_nonces_change = 1;
            asset_allowance_staker_pool_change = 0;

            address staker = vm.addr(i);

            _assertMintWithPermit(staker, i, mintAmount, true);
        }
    }
}
