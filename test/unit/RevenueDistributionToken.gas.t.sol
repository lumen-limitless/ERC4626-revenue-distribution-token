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

contract GasTests is PoolTestBase {
    function setUp() public virtual override {
        asset = new MockERC20();
        pool = new MockRevenueDistributionToken(address(this), address(asset), 1e30);

        asset.mint(address(this), 1000 ether);
        asset.approve(address(pool), type(uint256).max);
        pool.deposit(1 ether, address(this));

        asset.transfer(address(pool), 100 ether);
        pool.updateVestingSchedule(DURATION);

        vm.warp(START);
    }

    function test_gas_deposit() public {
        vm.warp(START + 3 days);

        pool.deposit(1 ether, address(this));
    }

    function test_gas_mint() public {
        vm.warp(START + 3 days);

        pool.mint(1 ether, address(this));
    }

    function test_gas_withdraw() public {
        vm.warp(START + 3 days);

        pool.withdraw(0.5 ether, address(this), address(this));
    }

    function test_gas_redeem() public {
        vm.warp(START + 3 days);

        pool.redeem(0.5 ether, address(this), address(this));
    }

    function test_gas_transfer() public {
        vm.warp(START + 3 days);

        pool.transfer(TESTER, 0.5 ether);
    }
}
