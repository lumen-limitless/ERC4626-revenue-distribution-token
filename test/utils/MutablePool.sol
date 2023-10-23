// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {RevenueDistributionToken} from "src/RevenueDistributionToken.sol";
import {ERC20} from "../../src/ERC20.sol";

contract MutablePool is RevenueDistributionToken {
    constructor(string memory name_, string memory symbol_, address owner_, ERC20 underlying_)
        RevenueDistributionToken(name_, symbol_, owner_, address(underlying_), 1e30)
    {}

    function setOwner(address owner_) external {
        _setOwner(owner_);
    }
}
