// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import {BaseTest} from "./BaseTest.sol";
import {MockRevenueDistributionToken} from "../mocks/MockRevenueDistributionToken.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract PoolTestBase is BaseTest {
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    uint256 constant DURATION = 7 days;
    uint256 constant PRECISION = 1e30;
    uint256 constant START = 10_000_000; //start at non-zero block
    //constant address for testing
    address constant TESTER = address(0x69);
    uint256 constant sampleAssetsToConvert = 1e18;
    uint256 constant sampleSharesToConvert = 1e18;

    uint256 nonce = 0;
    uint256 deadline = 5_000_000_000; // Timestamp far in the future

    MockERC20 public asset;
    MockRevenueDistributionToken public pool;

    function setUp() public virtual {
        asset = new MockERC20();
        pool = new MockRevenueDistributionToken( address(this), address(asset), 1e30 );

        vm.warp(START);
    }

    // Deposit asset into RevenueDistributionToken
    function _depositAsset(address asset_, address staker_, uint256 depositAmount_) internal {
        MockERC20(asset_).mint(staker_, depositAmount_);

        vm.startPrank(staker_);
        asset.approve(address(pool), depositAmount_);
        pool.deposit(depositAmount_, staker_);
        vm.stopPrank();
    }

    // Transfer funds into RevenueDistributionToken and update the vesting schedule
    function _transferAndUpdateVesting(address asset_, address pool_, uint256 amount_, uint256 duration_) internal {
        MockERC20(asset_).mint(address(this), amount_);
        MockERC20(asset_).transfer(address(pool), amount_);
        MockRevenueDistributionToken(pool_).updateVestingSchedule(duration_);
    }

    // Returns an ERC-2612 `permit` digest for the `owner` to sign
    function _getDigest(address owner_, address spender_, uint256 value_, uint256 nonce_, uint256 deadline_)
        internal
        view
        returns (bytes32 digest_)
    {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                asset.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, owner_, spender_, value_, nonce_, deadline_))
            )
        );
    }

    function _getMinDeposit(address pool_) internal view returns (uint256 minDeposit_) {
        minDeposit_ = (MockRevenueDistributionToken(pool_).totalAssets() - 1)
            / MockRevenueDistributionToken(pool_).totalSupply() + 1;
    }

    // Returns a valid `permit` signature signed by this contract's `owner` address
    function _getValidPermitSignature(
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint256 ownerSk_
    ) internal view returns (uint8 v_, bytes32 r_, bytes32 s_) {
        return vm.sign(ownerSk_, _getDigest(owner_, spender_, value_, nonce, deadline_));
    }
}
