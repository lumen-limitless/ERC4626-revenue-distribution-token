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

// =============================================================
//                       CONSTRUCTOR TEST
// =============================================================

contract ConstructorTests is BaseTest {
    function test_constructor() public {
        MockERC20 asset = new MockERC20();

        //reverts if initialOwner is address(0)
        vm.expectRevert();
        MockRevenueDistributionToken pool = new MockRevenueDistributionToken(address(0), address(asset), 1e30 );

        //reverts if asset is address(0)
        vm.expectRevert();
        pool = new MockRevenueDistributionToken( address(this), address(0), 1e30 );

        //successful constructor
        pool = new MockRevenueDistributionToken( address(this), address(asset), 1e30 );

        assertEq(pool.owner(), address(this));
        assertEq(pool.decimals(), 18);
        assertEq(pool.asset(), address(asset));
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.totalAssets(), 0);
    }
}
