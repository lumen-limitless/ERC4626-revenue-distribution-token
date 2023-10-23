// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.7;

import {ERC20} from "solady/tokens/ERC20.sol";
import {InvariantTest} from "../utils/InvariantTest.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {BaseTest} from "../base/BaseTest.sol";
import {InvariantERC20User} from "../accounts/ERC20User.sol";
import {InvariantOwner} from "../accounts/Owner.sol";
import {InvariantStakerManager} from "../accounts/Staker.sol";
import {Warper} from "../accounts/Warper.sol";
import {MutablePool} from "../utils/MutablePool.sol";

// Invariant 1:  totalAssets <= underlying balance of contract (with rounding)
// Invariant 2:  ∑ balanceOfAssets == totalAssets (with rounding)
// Invariant 3:  totalSupply <= totalAssets
// Invariant 4:  convertToAssets(totalSupply) == totalAssets (with rounding)
// Invariant 5:  exchangeRate >= `precision`
// Invariant 6:  freeAssets <= totalAssets
// Invariant 7:  balanceOfAssets >= balanceOf
// Invariant 8:  freeAssets <= underlying balance
// Invariant 9:  issuanceRate == 0 (if post vesting)
// Invariant 10: issuanceRate > 0 (if mid vesting)

contract Invariants is BaseTest, InvariantTest {
    InvariantERC20User internal _erc20User;
    InvariantOwner internal _owner;
    InvariantStakerManager internal _stakerManager;
    MockERC20 internal _underlying;
    MutablePool internal _pool;
    Warper internal _warper;

    function setUp() public virtual {
        _underlying = new MockERC20();
        _pool = new MutablePool("Vesting Pool", "VP", address(this), ERC20(address(_underlying)));
        _erc20User = new InvariantERC20User(address(_pool), address(_underlying));
        _stakerManager = new InvariantStakerManager(address(_pool), address(_underlying));
        _owner = new InvariantOwner(address(_pool), address(_underlying));
        _warper = new Warper(address(_pool));

        // Required to prevent `acceptOwner` from being a target function
        // TODO: Investigate hevm.store error: `hevm: internal error: unexpected failure code`
        _pool.setOwner(address(_owner));

        // Performs random transfers of underlying into contract
        addTargetContract(address(_erc20User));

        // Performs random transfers of underlying into contract
        // Performs random updateVestingSchedule calls
        addTargetContract(address(_owner));

        // Performs random instantiations of new staker users
        // Performs random deposit calls from a random instantiated staker
        // Performs random withdraw calls from a random instantiated staker
        // Performs random redeem calls from a random instantiated staker
        addTargetContract(address(_stakerManager));

        // Performs random warps forward in time
        addTargetContract(address(_warper));

        // Create one staker to prevent underflow on index calculations
        _stakerManager.createStaker();
    }

    function invariant_totalAssets_lte_underlyingBalance() public {
        assertTrue(_pool.totalAssets() <= _underlying.balanceOf(address(_pool)));
    }

    function invariant_sumBalanceOfAssets_eq_totalAssets() public {
        // Only relevant if deposits exist
        if (_pool.totalSupply() > 0) {
            uint256 sumBalanceOfAssets;
            uint256 stakerCount = _stakerManager.getStakerCount();

            for (uint256 i; i < stakerCount; ++i) {
                sumBalanceOfAssets += _pool.balanceOfAssets(address(_stakerManager.stakers(i)));
            }

            assertTrue(sumBalanceOfAssets <= _pool.totalAssets());
            assertWithinDiff(sumBalanceOfAssets, _pool.totalAssets(), stakerCount); // Rounding error of one per user
        }
    }

    function invariant_totalSupply_lte_totalAssets() public {
        assertTrue(_pool.totalSupply() <= _pool.totalAssets());
    }

    function invariant_totalSupply_times_exchangeRate_eq_totalAssets() public {
        if (_pool.totalSupply() > 0) {
            assertWithinDiff(_pool.convertToAssets(_pool.totalSupply()), _pool.totalAssets(), 1); // One division
        }
    }

    // TODO: figure out if there's a replacement for this one involving convertTo* functions. I think Invariant 3: totalSupply <= totalAssets covers this.
    // function invariant_exchangeRate_gte_precision() public {
    //     assertTrue(_pool.exchangeRate() >= _pool.precision());
    // }

    function invariant_freeAssets_lte_totalAssets() public {
        assertTrue(_pool.freeAssets() <= _pool.totalAssets());
    }

    function invariant_balanceOfAssets_gte_balanceOf() public {
        for (uint256 i; i < _stakerManager.getStakerCount(); ++i) {
            address staker = address(_stakerManager.stakers(i));
            assertTrue(_pool.balanceOfAssets(staker) >= _pool.balanceOf(staker));
        }
    }

    function invariant_freeAssets_lte_underlyingBalance() public {
        assertTrue(_pool.freeAssets() <= _underlying.balanceOf(address(_pool)));
    }

    function invariant_issuanceRate_eq_zero_ifPostVesting() public {
        if (block.timestamp > _pool.vestingPeriodFinish() && _pool.lastUpdated() > _pool.vestingPeriodFinish()) {
            assertTrue(_pool.issuanceRate() == 0);
        }
    }

    function invariant_issuanceRate_gt_zero_ifMidVesting() public {
        if (block.timestamp <= _pool.vestingPeriodFinish()) {
            assertTrue(_pool.issuanceRate() > 0);
        }
    }
}
