// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {MockRevenueDistributionToken} from "../mocks/MockRevenueDistributionToken.sol";
import {ERC20} from "../../src/ERC20.sol";

contract MutablePool is MockRevenueDistributionToken {
    constructor(address owner_, ERC20 underlying_) MockRevenueDistributionToken(owner_, address(underlying_), 1e30) {}

    function setOwner(address owner_) external {
        _setOwner(owner_);
    }
}
