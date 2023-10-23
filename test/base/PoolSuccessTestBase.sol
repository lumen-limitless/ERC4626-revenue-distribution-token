// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {PoolTestBase} from "./PoolTestBase.sol";
import {Staker} from "../accounts/Staker.sol";

contract PoolSuccessTestBase is PoolTestBase {
    // =============================================================
    //                   PRE_STATE VARIABLES
    // =============================================================

    // NOTE: Pre state variables are kept in storage to avoid stack too deep
    int256 pool_allowance_staker_caller;
    int256 pool_balanceOf_staker;
    int256 pool_totalSupply;
    int256 pool_freeAssets;
    int256 pool_totalAssets;
    int256 pool_convertToAssets;
    int256 pool_convertToShares;
    int256 pool_issuanceRate;
    int256 pool_lastUpdated;
    int256 asset_balanceOf_caller;
    int256 asset_balanceOf_staker;
    int256 asset_balanceOf_pool;
    int256 asset_nonces;
    int256 asset_allowance_staker_pool;

    // =============================================================
    //              STATE CHANGE ASSERTION VARIABLES
    // =============================================================

    // NOTE: State change assertion variables are kept in storage to avoid stack too deep
    int256 pool_allowance_staker_caller_change;
    int256 pool_balanceOf_caller_change;
    int256 pool_balanceOf_staker_change;
    int256 pool_totalSupply_change;
    int256 pool_freeAssets_change;
    int256 pool_totalAssets_change;
    int256 pool_convertToAssets_change;
    int256 pool_convertToShares_change;
    int256 pool_issuanceRate_change;
    int256 pool_lastUpdated_change;
    int256 asset_balanceOf_caller_change;
    int256 asset_balanceOf_staker_change;
    int256 asset_balanceOf_pool_change;
    int256 asset_nonces_change;
    int256 asset_allowance_staker_pool_change;

    // =============================================================
    //                       ASSERTION UTILITY FUNCTIONS
    // =============================================================

    function _assertDeposit(address staker_, uint256 depositAmount_, bool fuzzed_) internal {
        asset.mint(staker_, depositAmount_);

        vm.prank(staker_);
        asset.approve(address(pool), depositAmount_);

        pool_balanceOf_staker = _toInt256(pool.balanceOf(staker_));
        pool_totalSupply = _toInt256(pool.totalSupply());
        pool_freeAssets = _toInt256(pool.freeAssets());
        pool_totalAssets = _toInt256(pool.totalAssets());
        pool_convertToAssets = _toInt256(pool.convertToAssets(sampleSharesToConvert));
        pool_convertToShares = _toInt256(pool.convertToShares(sampleAssetsToConvert));
        pool_issuanceRate = _toInt256(pool.issuanceRate());
        pool_lastUpdated = _toInt256(pool.lastUpdated());

        asset_balanceOf_staker = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_pool = _toInt256(asset.balanceOf(address(pool)));
        asset_allowance_staker_pool = _toInt256(asset.allowance(staker_, address(pool)));

        vm.prank(staker_);
        uint256 shares = pool.deposit(depositAmount_, staker_);

        assertEq(shares, pool.balanceOf(staker_) - _toUint256(pool_balanceOf_staker));

        _assertWithinOne(pool.balanceOf(staker_), _toUint256(pool_balanceOf_staker + pool_balanceOf_staker_change));
        _assertWithinOne(pool.totalSupply(), _toUint256(pool_totalSupply + pool_totalSupply_change));
        _assertWithinOne(pool.freeAssets(), _toUint256(pool_freeAssets + pool_freeAssets_change));
        _assertWithinOne(pool.totalAssets(), _toUint256(pool_totalAssets + pool_totalAssets_change));
        _assertWithinOne(pool.issuanceRate(), _toUint256(pool_issuanceRate + pool_issuanceRate_change));

        if (!fuzzed_) {
            // TODO: Determine a way to mathematically determine inaccuracy based on inputs, so can be used in fuzz tests
            _assertWithinOne(
                pool.convertToAssets(sampleSharesToConvert),
                _toUint256(pool_convertToAssets + pool_convertToAssets_change)
            );
            _assertWithinOne(
                pool.convertToShares(sampleAssetsToConvert),
                _toUint256(pool_convertToShares + pool_convertToShares_change)
            );
        }

        assertEq(pool.lastUpdated(), _toUint256(pool_lastUpdated + pool_lastUpdated_change));

        _assertWithinOne(asset.balanceOf(staker_), _toUint256(asset_balanceOf_staker + asset_balanceOf_staker_change));
        _assertWithinOne(asset.balanceOf(address(pool)), _toUint256(asset_balanceOf_pool + asset_balanceOf_pool_change));
        _assertWithinOne(
            asset.allowance(staker_, address(pool)),
            _toUint256(asset_allowance_staker_pool + asset_allowance_staker_pool_change)
        );
    }

    function _assertMint(address staker_, uint256 mintAmount_, bool fuzzed_) internal {
        uint256 assetAmount = pool.previewMint(mintAmount_);

        asset.mint(staker_, assetAmount);

        vm.prank(staker_);
        asset.approve(address(pool), assetAmount);

        pool_balanceOf_staker = _toInt256(pool.balanceOf(staker_));
        pool_totalSupply = _toInt256(pool.totalSupply());
        pool_freeAssets = _toInt256(pool.freeAssets());
        pool_totalAssets = _toInt256(pool.totalAssets());
        pool_convertToAssets = _toInt256(pool.convertToAssets(sampleSharesToConvert));
        pool_convertToShares = _toInt256(pool.convertToShares(sampleAssetsToConvert));
        pool_issuanceRate = _toInt256(pool.issuanceRate());
        pool_lastUpdated = _toInt256(pool.lastUpdated());

        asset_balanceOf_staker = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_pool = _toInt256(asset.balanceOf(address(pool)));
        asset_allowance_staker_pool = _toInt256(asset.allowance(staker_, address(pool)));

        vm.prank(staker_);
        uint256 depositedAmount = pool.mint(mintAmount_, staker_);

        assertEq(depositedAmount, _toUint256(asset_balanceOf_staker) - asset.balanceOf(staker_));

        _assertWithinOne(pool.balanceOf(staker_), _toUint256(pool_balanceOf_staker + pool_balanceOf_staker_change));
        _assertWithinOne(pool.totalSupply(), _toUint256(pool_totalSupply + pool_totalSupply_change));
        _assertWithinOne(pool.freeAssets(), _toUint256(pool_freeAssets + pool_freeAssets_change));
        _assertWithinOne(pool.totalAssets(), _toUint256(pool_totalAssets + pool_totalAssets_change));
        _assertWithinOne(pool.issuanceRate(), _toUint256(pool_issuanceRate + pool_issuanceRate_change));

        if (!fuzzed_) {
            _assertWithinOne(
                pool.convertToAssets(sampleSharesToConvert),
                _toUint256(pool_convertToAssets + pool_convertToAssets_change)
            );
            _assertWithinOne(
                pool.convertToShares(sampleAssetsToConvert),
                _toUint256(pool_convertToShares + pool_convertToShares_change)
            );
        }

        assertEq(pool.lastUpdated(), _toUint256(pool_lastUpdated + pool_lastUpdated_change));

        _assertWithinOne(asset.balanceOf(staker_), _toUint256(asset_balanceOf_staker + asset_balanceOf_staker_change));
        _assertWithinOne(asset.balanceOf(address(pool)), _toUint256(asset_balanceOf_pool + asset_balanceOf_pool_change));
        _assertWithinOne(
            asset.allowance(staker_, address(pool)),
            _toUint256(asset_allowance_staker_pool + asset_allowance_staker_pool_change)
        );
    }

    function _assertDepositWithPermit(address staker_, uint256 stakerPrivateKey_, uint256 depositAmount_, bool fuzzed_)
        internal
    {
        asset.mint(staker_, depositAmount_);

        pool_balanceOf_staker = _toInt256(pool.balanceOf(staker_));
        pool_totalSupply = _toInt256(pool.totalSupply());
        pool_freeAssets = _toInt256(pool.freeAssets());
        pool_totalAssets = _toInt256(pool.totalAssets());
        pool_convertToAssets = _toInt256(pool.convertToAssets(sampleSharesToConvert));
        pool_convertToShares = _toInt256(pool.convertToShares(sampleAssetsToConvert));
        pool_issuanceRate = _toInt256(pool.issuanceRate());
        pool_lastUpdated = _toInt256(pool.lastUpdated());

        asset_balanceOf_staker = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_pool = _toInt256(asset.balanceOf(address(pool)));
        asset_nonces = _toInt256(asset.nonces(staker_));
        asset_allowance_staker_pool = _toInt256(asset.allowance(staker_, address(pool)));

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker_, address(pool), depositAmount_, block.timestamp, stakerPrivateKey_);
        vm.prank(staker_);
        uint256 shares = pool.depositWithPermit(depositAmount_, staker_, block.timestamp, v, r, s);

        assertEq(shares, pool.balanceOf(staker_) - _toUint256(pool_balanceOf_staker));

        _assertWithinOne(pool.balanceOf(staker_), _toUint256(pool_balanceOf_staker + pool_balanceOf_staker_change));
        _assertWithinOne(pool.totalSupply(), _toUint256(pool_totalSupply + pool_totalSupply_change));
        _assertWithinOne(pool.freeAssets(), _toUint256(pool_freeAssets + pool_freeAssets_change));
        _assertWithinOne(pool.totalAssets(), _toUint256(pool_totalAssets + pool_totalAssets_change));
        _assertWithinOne(pool.issuanceRate(), _toUint256(pool_issuanceRate + pool_issuanceRate_change));

        if (!fuzzed_) {
            // TODO: Determine a way to mathematically determine inaccuracy based on inputs, so can be used in fuzz tests
            _assertWithinOne(
                pool.convertToAssets(sampleSharesToConvert),
                _toUint256(pool_convertToAssets + pool_convertToAssets_change)
            );
            _assertWithinOne(
                pool.convertToShares(sampleAssetsToConvert),
                _toUint256(pool_convertToShares + pool_convertToShares_change)
            );
        }

        assertEq(pool.lastUpdated(), _toUint256(pool_lastUpdated + pool_lastUpdated_change));

        _assertWithinOne(asset.balanceOf(staker_), _toUint256(asset_balanceOf_staker + asset_balanceOf_staker_change));
        _assertWithinOne(asset.balanceOf(address(pool)), _toUint256(asset_balanceOf_pool + asset_balanceOf_pool_change));

        assertEq(
            asset.allowance(staker_, address(pool)),
            _toUint256(asset_allowance_staker_pool + asset_allowance_staker_pool_change)
        );
        assertEq(asset.nonces(staker_), _toUint256(asset_nonces + asset_nonces_change));
    }

    function _assertMintWithPermit(address staker_, uint256 stakerPrivateKey_, uint256 mintAmount_, bool fuzzed_)
        internal
    {
        uint256 maxAssets = pool.previewMint(mintAmount_);
        asset.mint(staker_, maxAssets);

        pool_balanceOf_staker = _toInt256(pool.balanceOf(staker_));
        pool_totalSupply = _toInt256(pool.totalSupply());
        pool_freeAssets = _toInt256(pool.freeAssets());
        pool_totalAssets = _toInt256(pool.totalAssets());
        pool_convertToAssets = _toInt256(pool.convertToAssets(sampleSharesToConvert));
        pool_convertToShares = _toInt256(pool.convertToShares(sampleAssetsToConvert));
        pool_issuanceRate = _toInt256(pool.issuanceRate());
        pool_lastUpdated = _toInt256(pool.lastUpdated());

        asset_balanceOf_staker = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_pool = _toInt256(asset.balanceOf(address(pool)));
        asset_nonces = _toInt256(asset.nonces(staker_));
        asset_allowance_staker_pool = _toInt256(asset.allowance(staker_, address(pool)));

        (uint8 v, bytes32 r, bytes32 s) =
            _getValidPermitSignature(staker_, address(pool), maxAssets, block.timestamp, stakerPrivateKey_);
        vm.prank(staker_);
        uint256 depositedAmount = pool.mintWithPermit(mintAmount_, staker_, maxAssets, block.timestamp, v, r, s);

        assertEq(depositedAmount, _toUint256(asset_balanceOf_staker) - asset.balanceOf(staker_));

        _assertWithinOne(pool.balanceOf(staker_), _toUint256(pool_balanceOf_staker + pool_balanceOf_staker_change));
        _assertWithinOne(pool.totalSupply(), _toUint256(pool_totalSupply + pool_totalSupply_change));
        _assertWithinOne(pool.freeAssets(), _toUint256(pool_freeAssets + pool_freeAssets_change));
        _assertWithinOne(pool.totalAssets(), _toUint256(pool_totalAssets + pool_totalAssets_change));
        _assertWithinOne(pool.issuanceRate(), _toUint256(pool_issuanceRate + pool_issuanceRate_change));

        if (!fuzzed_) {
            // TODO: Determine a way to mathematically determine inaccuracy based on inputs, so can be used in fuzz tests
            _assertWithinOne(
                pool.convertToAssets(sampleSharesToConvert),
                _toUint256(pool_convertToAssets + pool_convertToAssets_change)
            );
            _assertWithinOne(
                pool.convertToShares(sampleAssetsToConvert),
                _toUint256(pool_convertToShares + pool_convertToShares_change)
            );
        }

        assertEq(pool.lastUpdated(), _toUint256(pool_lastUpdated + pool_lastUpdated_change));

        _assertWithinOne(asset.balanceOf(staker_), _toUint256(asset_balanceOf_staker + asset_balanceOf_staker_change));
        _assertWithinOne(asset.balanceOf(address(pool)), _toUint256(asset_balanceOf_pool + asset_balanceOf_pool_change));

        assertEq(
            asset.allowance(staker_, address(pool)),
            _toUint256(asset_allowance_staker_pool + asset_allowance_staker_pool_change)
        );
        assertEq(asset.nonces(staker_), _toUint256(asset_nonces + asset_nonces_change));
    }

    function _assertWithdrawCallerNotOwner(address caller_, address staker_, uint256 withdrawAmount_, bool fuzzed_)
        internal
    {
        pool_allowance_staker_caller = _toInt256(pool.allowance(staker_, caller_));
        pool_balanceOf_staker = _toInt256(pool.balanceOf(staker_));
        pool_totalSupply = _toInt256(pool.totalSupply());
        pool_freeAssets = _toInt256(pool.freeAssets());
        pool_totalAssets = _toInt256(pool.totalAssets());
        pool_convertToAssets = _toInt256(pool.convertToAssets(sampleSharesToConvert));
        pool_convertToShares = _toInt256(pool.convertToShares(sampleAssetsToConvert));
        pool_issuanceRate = _toInt256(pool.issuanceRate());
        pool_lastUpdated = _toInt256(pool.lastUpdated());

        asset_balanceOf_staker = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_caller = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_pool = _toInt256(asset.balanceOf(address(pool)));

        uint256 sharesBurned = Staker(caller_).pool_withdraw(address(pool), withdrawAmount_, caller_, staker_);

        assertEq(sharesBurned, _toUint256(pool_balanceOf_staker) - pool.balanceOf(staker_)); // Number of shares burned

        _assertWithinOne(
            pool.allowance(staker_, caller_),
            _toUint256(pool_allowance_staker_caller + pool_allowance_staker_caller_change)
        );
        _assertWithinOne(pool.balanceOf(staker_), _toUint256(pool_balanceOf_staker + pool_balanceOf_staker_change));
        _assertWithinOne(pool.totalSupply(), _toUint256(pool_totalSupply + pool_totalSupply_change));
        _assertWithinOne(pool.freeAssets(), _toUint256(pool_freeAssets + pool_freeAssets_change));
        _assertWithinOne(pool.totalAssets(), _toUint256(pool_totalAssets + pool_totalAssets_change));
        _assertWithinOne(pool.issuanceRate(), _toUint256(pool_issuanceRate + pool_issuanceRate_change));

        // In fuzzed tests, depending on inputs these values can be different so they are left out of assertions.
        if (!fuzzed_) {
            _assertWithinOne(
                pool.convertToAssets(sampleSharesToConvert),
                _toUint256(pool_convertToAssets + pool_convertToAssets_change)
            );
            _assertWithinOne(
                pool.convertToShares(sampleAssetsToConvert),
                _toUint256(pool_convertToShares + pool_convertToShares_change)
            );
        }

        assertEq(pool.lastUpdated(), _toUint256(pool_lastUpdated + pool_lastUpdated_change));

        _assertWithinOne(asset.balanceOf(staker_), _toUint256(asset_balanceOf_staker + asset_balanceOf_staker_change));
        _assertWithinOne(asset.balanceOf(caller_), _toUint256(asset_balanceOf_caller + asset_balanceOf_caller_change));
        _assertWithinOne(asset.balanceOf(address(pool)), _toUint256(asset_balanceOf_pool + asset_balanceOf_pool_change));
    }

    function _assertRedeemCallerNotOwner(address caller_, address staker_, uint256 redeemAmount_, bool fuzzed_)
        internal
    {
        pool_allowance_staker_caller = _toInt256(pool.allowance(staker_, caller_));
        pool_balanceOf_staker = _toInt256(pool.balanceOf(staker_));
        pool_totalSupply = _toInt256(pool.totalSupply());
        pool_freeAssets = _toInt256(pool.freeAssets());
        pool_totalAssets = _toInt256(pool.totalAssets());
        pool_convertToAssets = _toInt256(pool.convertToAssets(sampleSharesToConvert));
        pool_convertToShares = _toInt256(pool.convertToShares(sampleAssetsToConvert));
        pool_issuanceRate = _toInt256(pool.issuanceRate());
        pool_lastUpdated = _toInt256(pool.lastUpdated());

        asset_balanceOf_staker = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_caller = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_pool = _toInt256(asset.balanceOf(address(pool)));

        uint256 fundsWithdrawn = Staker(caller_).pool_redeem(address(pool), redeemAmount_, caller_, staker_);

        assertEq(fundsWithdrawn, asset.balanceOf(caller_) - _toUint256(asset_balanceOf_caller)); // Total funds withdrawn

        _assertWithinOne(pool.balanceOf(staker_), _toUint256(pool_balanceOf_staker + pool_balanceOf_staker_change));
        _assertWithinOne(pool.totalSupply(), _toUint256(pool_totalSupply + pool_totalSupply_change));
        _assertWithinOne(pool.freeAssets(), _toUint256(pool_freeAssets + pool_freeAssets_change));
        _assertWithinOne(pool.totalAssets(), _toUint256(pool_totalAssets + pool_totalAssets_change));

        // In fuzzed tests, depending on inputs these values can be different so they are left out of assertions.
        if (!fuzzed_) {
            _assertWithinOne(
                pool.convertToAssets(sampleSharesToConvert),
                _toUint256(pool_convertToAssets + pool_convertToAssets_change)
            );
            _assertWithinOne(
                pool.convertToShares(sampleAssetsToConvert),
                _toUint256(pool_convertToShares + pool_convertToShares_change)
            );
            _assertWithinOne(pool.issuanceRate(), _toUint256(pool_issuanceRate + pool_issuanceRate_change));
        }

        assertEq(pool.lastUpdated(), _toUint256(pool_lastUpdated + pool_lastUpdated_change));

        _assertWithinOne(asset.balanceOf(staker_), _toUint256(asset_balanceOf_staker + asset_balanceOf_staker_change));
        _assertWithinOne(asset.balanceOf(caller_), _toUint256(asset_balanceOf_caller + asset_balanceOf_caller_change));
        _assertWithinOne(asset.balanceOf(address(pool)), _toUint256(asset_balanceOf_pool + asset_balanceOf_pool_change));

        assertEq(
            asset.allowance(staker_, address(pool)),
            _toUint256(asset_allowance_staker_pool + asset_allowance_staker_pool_change)
        );
    }

    function _assertWithdraw(address staker_, uint256 withdrawAmount_, bool fuzzed_) internal {
        pool_balanceOf_staker = _toInt256(pool.balanceOf(staker_));
        pool_totalSupply = _toInt256(pool.totalSupply());
        pool_freeAssets = _toInt256(pool.freeAssets());
        pool_totalAssets = _toInt256(pool.totalAssets());
        pool_convertToAssets = _toInt256(pool.convertToAssets(sampleSharesToConvert));
        pool_convertToShares = _toInt256(pool.convertToShares(sampleAssetsToConvert));
        pool_issuanceRate = _toInt256(pool.issuanceRate());
        pool_lastUpdated = _toInt256(pool.lastUpdated());

        asset_balanceOf_staker = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_caller = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_pool = _toInt256(asset.balanceOf(address(pool)));

        vm.prank(staker_);
        uint256 sharesBurned = pool.withdraw(withdrawAmount_, staker_, staker_);

        assertEq(sharesBurned, _toUint256(pool_balanceOf_staker) - pool.balanceOf(staker_)); // Number of shares burned

        _assertWithinOne(pool.balanceOf(staker_), _toUint256(pool_balanceOf_staker + pool_balanceOf_staker_change));
        _assertWithinOne(pool.totalSupply(), _toUint256(pool_totalSupply + pool_totalSupply_change));
        _assertWithinOne(pool.freeAssets(), _toUint256(pool_freeAssets + pool_freeAssets_change));
        _assertWithinOne(pool.totalAssets(), _toUint256(pool_totalAssets + pool_totalAssets_change));
        _assertWithinOne(pool.issuanceRate(), _toUint256(pool_issuanceRate + pool_issuanceRate_change));

        // In fuzzed tests, depending on inputs these values can be different so they are left out of assertions.
        if (!fuzzed_) {
            _assertWithinOne(
                pool.convertToAssets(sampleSharesToConvert),
                _toUint256(pool_convertToAssets + pool_convertToAssets_change)
            );
            _assertWithinOne(
                pool.convertToShares(sampleAssetsToConvert),
                _toUint256(pool_convertToShares + pool_convertToShares_change)
            );
        }

        assertEq(pool.lastUpdated(), _toUint256(pool_lastUpdated + pool_lastUpdated_change));

        _assertWithinOne(asset.balanceOf(staker_), _toUint256(asset_balanceOf_staker + asset_balanceOf_staker_change));
        _assertWithinOne(asset.balanceOf(address(pool)), _toUint256(asset_balanceOf_pool + asset_balanceOf_pool_change));
    }

    function _assertRedeem(address staker_, uint256 redeemAmount_, bool fuzzed_) internal {
        pool_balanceOf_staker = _toInt256(pool.balanceOf(staker_));
        pool_totalSupply = _toInt256(pool.totalSupply());
        pool_freeAssets = _toInt256(pool.freeAssets());
        pool_totalAssets = _toInt256(pool.totalAssets());
        pool_convertToAssets = _toInt256(pool.convertToAssets(sampleSharesToConvert));
        pool_convertToShares = _toInt256(pool.convertToShares(sampleAssetsToConvert));
        pool_issuanceRate = _toInt256(pool.issuanceRate());
        pool_lastUpdated = _toInt256(pool.lastUpdated());

        asset_balanceOf_staker = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_caller = _toInt256(asset.balanceOf(staker_));
        asset_balanceOf_pool = _toInt256(asset.balanceOf(address(pool)));

        vm.prank(staker_);
        uint256 fundsWithdrawn = pool.redeem(redeemAmount_, staker_, staker_);

        assertEq(fundsWithdrawn, asset.balanceOf(staker_) - _toUint256(asset_balanceOf_staker)); // Total funds withdrawn

        _assertWithinOne(pool.balanceOf(staker_), _toUint256(pool_balanceOf_staker + pool_balanceOf_staker_change));
        _assertWithinOne(pool.totalSupply(), _toUint256(pool_totalSupply + pool_totalSupply_change));
        _assertWithinOne(pool.freeAssets(), _toUint256(pool_freeAssets + pool_freeAssets_change));
        _assertWithinOne(pool.totalAssets(), _toUint256(pool_totalAssets + pool_totalAssets_change));
        _assertWithinOne(pool.issuanceRate(), _toUint256(pool_issuanceRate + pool_issuanceRate_change));

        // In fuzzed tests, depending on inputs these values can be different so they are left out of assertions.
        if (!fuzzed_) {
            _assertWithinOne(
                pool.convertToAssets(sampleSharesToConvert),
                _toUint256(pool_convertToAssets + pool_convertToAssets_change)
            );
            _assertWithinOne(
                pool.convertToShares(sampleAssetsToConvert),
                _toUint256(pool_convertToShares + pool_convertToShares_change)
            );
        }

        assertEq(pool.lastUpdated(), _toUint256(pool_lastUpdated + pool_lastUpdated_change));

        _assertWithinOne(asset.balanceOf(staker_), _toUint256(asset_balanceOf_staker + asset_balanceOf_staker_change));
        _assertWithinOne(asset.balanceOf(address(pool)), _toUint256(asset_balanceOf_pool + asset_balanceOf_pool_change));
    }

    // =============================================================
    //                       GENERAL UTILITY FUNCTIONS
    // =============================================================

    function _assertWithinOne(uint256 expected_, uint256 actual_) internal {
        assertWithinDiff(actual_, expected_, 1);
    }

    function _toInt256(uint256 unsigned_) internal pure returns (int256 signed_) {
        signed_ = int256(unsigned_);
        require(signed_ >= 0, "TO_INT256_OVERFLOW");
    }

    function _toUint256(int256 signed_) internal pure returns (uint256 unsigned_) {
        require(signed_ >= 0, "TO_UINT256_NEGATIVE");
        return uint256(signed_);
    }
}
