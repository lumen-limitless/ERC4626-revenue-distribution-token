// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {ERC20User} from "../accounts/ERC20User.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {BaseTest} from "../base/BaseTest.sol";
import {RevenueDistributionToken as RDT} from "src/RevenueDistributionToken.sol";

contract Staker is ERC20User {
    function pool_deposit(address token_, uint256 assets_) external returns (uint256 shares_) {
        shares_ = RDT(token_).deposit(assets_, address(this));
    }

    function pool_deposit(address token_, uint256 assets_, address receiver_) external returns (uint256 shares_) {
        shares_ = RDT(token_).deposit(assets_, receiver_);
    }

    function pool_mint(address token_, uint256 shares_) external returns (uint256 assets_) {
        assets_ = RDT(token_).mint(shares_, address(this));
    }

    function pool_mint(address token_, uint256 shares_, address receiver_) external returns (uint256 assets_) {
        assets_ = RDT(token_).mint(shares_, receiver_);
    }

    function pool_redeem(address token_, uint256 shares_) external returns (uint256 assets_) {
        assets_ = RDT(token_).redeem(shares_, address(this), address(this));
    }

    function pool_redeem(address token_, uint256 shares_, address recipient_, address owner_)
        external
        returns (uint256 assets_)
    {
        assets_ = RDT(token_).redeem(shares_, recipient_, owner_);
    }

    function pool_withdraw(address token_, uint256 assets_) external returns (uint256 shares_) {
        shares_ = RDT(token_).withdraw(assets_, address(this), address(this));
    }

    function pool_withdraw(address token_, uint256 assets_, address recipient_, address owner_)
        external
        returns (uint256 shares_)
    {
        shares_ = RDT(token_).withdraw(assets_, recipient_, owner_);
    }
}

contract InvariantStaker is BaseTest {
    RDT internal _pool;
    MockERC20 internal _underlying;

    constructor(address pool_, address underlying_) {
        _pool = RDT(pool_);
        _underlying = MockERC20(underlying_);
    }

    function deposit(uint256 assets_) external {
        // NOTE: The precision of the exchangeRate is equal to the amount of funds that can be deposited before rounding errors start to arise
        assets_ = constrictToRange(assets_, 1, 1e29); // 100 billion at WAD precision (1 less than 1e30 to avoid precision issues)

        uint256 startingBalance = _pool.balanceOf(address(this));
        uint256 shareAmount = _pool.previewDeposit(assets_);

        _underlying.mint(address(this), assets_);
        _underlying.approve(address(_pool), assets_);

        _pool.deposit(assets_, address(this));

        assertEq(_pool.balanceOf(address(this)), startingBalance + shareAmount); // Ensure successful deposit
    }

    function redeem(uint256 shares_) external {
        uint256 startingBalance = _pool.balanceOf(address(this));

        if (startingBalance > 0) {
            uint256 redeemAmount = constrictToRange(shares_, 1, _pool.balanceOf(address(this)));

            _pool.redeem(redeemAmount, address(this), address(this));

            assertEq(_pool.balanceOf(address(this)), startingBalance - redeemAmount);
        }
    }

    function withdraw(uint256 assets_) external {
        uint256 startingBalance = _underlying.balanceOf(address(this));

        if (startingBalance > 0) {
            uint256 withdrawAmount = constrictToRange(assets_, 1, _pool.balanceOfAssets(address(this)));

            _pool.withdraw(withdrawAmount, address(this), address(this));

            assertEq(_underlying.balanceOf(address(this)), startingBalance + withdrawAmount); // Ensure successful withdraw
        }
    }
}

contract InvariantStakerManager is BaseTest {
    address internal _pool;
    address internal _underlying;

    InvariantStaker[] public stakers;

    constructor(address pool_, address underlying_) {
        _pool = pool_;
        _underlying = underlying_;
    }

    function createStaker() external {
        InvariantStaker staker = new InvariantStaker(_pool, _underlying);
        stakers.push(staker);
    }

    function deposit(uint256 amount_, uint256 index_) external {
        stakers[constrictToRange(index_, 0, stakers.length - 1)].deposit(amount_);
    }

    function redeem(uint256 amount_, uint256 index_) external {
        stakers[constrictToRange(index_, 0, stakers.length - 1)].redeem(amount_);
    }

    function withdraw(uint256 amount_, uint256 index_) external {
        stakers[constrictToRange(index_, 0, stakers.length - 1)].withdraw(amount_);
    }

    function getStakerCount() external view returns (uint256 stakerCount_) {
        return stakers.length;
    }
}
