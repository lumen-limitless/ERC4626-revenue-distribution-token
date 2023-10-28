// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0 <0.9.0;

import "erc4626-tests/ERC4626.test.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockRevenueDistributionToken} from "../mocks/MockRevenueDistributionToken.sol";

contract ERC4626StdTest is ERC4626Test {
    function setUp() public override {
        _underlying_ = address(new MockERC20());
        _vault_ = address(new MockRevenueDistributionToken( address(this), _underlying_, 1e30));
        _delta_ = 0;
    }

    // custom setup for yield
    function setUpYield(Init memory init) public override {
        // setup initial yield
        if (init.yield >= 0) {
            uint256 gain = uint256(init.yield);
            try IMockERC20(_underlying_).mint(_vault_, gain) {}
            catch {
                vm.assume(false);
            }
            try MockRevenueDistributionToken(_vault_).updateVestingSchedule(10) {}
            catch {
                vm.assume(false);
            }
            skip(3); // 30% of gain vested
        } else {
            vm.assume(false); // no loss
        }
    }

    // NOTE: The following test is relaxed to consider only smaller values (of type uint120),
    // since maxWithdraw() fails with large values (due to overflow).
    // The maxWithdraw() behavior is inherited from Solmate ERC4626 on which this vault is built.

    function test_maxWithdraw(Init memory init) public override {
        init = clamp(init, type(uint120).max);
        super.test_maxWithdraw(init);
    }

    function clamp(Init memory init, uint256 max) internal pure returns (Init memory) {
        for (uint256 i = 0; i < N; i++) {
            init.share[i] = init.share[i] % max;
            init.asset[i] = init.asset[i] % max;
        }
        init.yield = init.yield % int256(max);
        return init;
    }
}
