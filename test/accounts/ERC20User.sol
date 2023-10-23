// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {BaseTest} from "../base/BaseTest.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

contract ERC20User {
    function erc20_approve(address token_, address spender_, uint256 amount_) external {
        ERC20(token_).approve(spender_, amount_);
    }

    function erc20_permit(
        address token_,
        address owner_,
        address spender_,
        uint256 amount_,
        uint256 deadline_,
        uint8 v_,
        bytes32 r_,
        bytes32 s_
    ) external {
        ERC20(token_).permit(owner_, spender_, amount_, deadline_, v_, r_, s_);
    }

    function erc20_transfer(address token_, address recipient_, uint256 amount_) external returns (bool success_) {
        return ERC20(token_).transfer(recipient_, amount_);
    }

    function erc20_transferFrom(address token_, address owner_, address recipient_, uint256 amount_)
        external
        returns (bool success_)
    {
        return ERC20(token_).transferFrom(owner_, recipient_, amount_);
    }
}

contract InvariantERC20User is BaseTest {
    address rdToken;
    MockERC20 underlying;

    uint256 public amountDeposited;

    constructor(address rdToken_, address underlying_) {
        rdToken = rdToken_;
        underlying = MockERC20(underlying_);
    }

    function erc20_transfer(uint256 amount_) external {
        uint256 startingBalance = underlying.balanceOf(address(rdToken));

        amount_ = constrictToRange(amount_, 1, 1e29); // 100 billion at WAD precision (1 less than 1e30 to avoid precision issues)

        underlying.mint(address(this), amount_);
        underlying.transfer(rdToken, amount_);

        assertEq(underlying.balanceOf(address(rdToken)), startingBalance + amount_); // Ensure successful transfer
    }
}
