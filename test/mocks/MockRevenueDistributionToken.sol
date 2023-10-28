// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {RevenueDistributionToken} from "../../src/RevenueDistributionToken.sol";

contract MockRevenueDistributionToken is RevenueDistributionToken {
    constructor(address owner_, address asset_, uint256 precision_)
        RevenueDistributionToken(owner_, asset_, precision_)
    {}

    function name() public pure override returns (string memory) {
        return "TEST POOL";
    }

    function symbol() public pure override returns (string memory) {
        return "TEST";
    }
}
