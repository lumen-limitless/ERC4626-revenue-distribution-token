// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract InvariantTest {
    address[] private _targetContracts;

    function addTargetContract(address newTargetContract_) internal {
        _targetContracts.push(newTargetContract_);
    }
}
