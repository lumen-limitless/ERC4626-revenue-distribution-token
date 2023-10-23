// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {ERC20} from "solady/tokens/ERC20.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {RevenueDistributionToken as RDT} from "../../src/RevenueDistributionToken.sol";
import {BaseTest} from "../base/BaseTest.sol";

contract Owner {
    // function pool_acceptOwnership(address rdt_) external {
    //     RDT(rdt_).acceptOwnership();
    // }

    function pool_setPendingOwner(address rdt_, address pendingOwner_) external {
        RDT(rdt_).transferOwnership(pendingOwner_);
    }

    function pool_updateVestingSchedule(address rdt_, uint256 vestingPeriod_)
        external
        returns (uint256 issuanceRate_, uint256 freeAssets_)
    {
        return RDT(rdt_).updateVestingSchedule(vestingPeriod_);
    }

    function erc20_transfer(address token_, address receiver_, uint256 amount_) external returns (bool success_) {
        return ERC20(token_).transfer(receiver_, amount_);
    }
}

contract InvariantOwner is BaseTest {
    RDT internal _pool;
    MockERC20 internal _underlying;

    uint256 numberOfCalls;

    uint256 public amountDeposited;

    constructor(address pool_, address underlying_) {
        _pool = RDT(pool_);
        _underlying = MockERC20(underlying_);
    }

    function pool_updateVestingSchedule(uint256 vestingPeriod_) external {
        // If there is nothing to vest, don't do anything.
        if (_underlying.balanceOf(address(_pool)) == _pool.totalAssets()) {
            return;
        }

        vestingPeriod_ = constrictToRange(vestingPeriod_, 1, 10_000 days);

        _pool.updateVestingSchedule(vestingPeriod_);

        assertEq(_pool.vestingPeriodFinish(), block.timestamp + vestingPeriod_);
    }

    function erc20_transfer(uint256 amount_) external {
        uint256 startingBalance = _underlying.balanceOf(address(_pool));

        amount_ = constrictToRange(amount_, 1e6, 1e29); // 100 billion at WAD precision (1 less than 1e30 to avoid precision issues)

        _underlying.mint(address(this), amount_);
        _underlying.transfer(address(_pool), amount_);

        assertEq(_underlying.balanceOf(address(_pool)), startingBalance + amount_); // Ensure successful transfer
    }
}
