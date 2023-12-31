// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Reentrancy guard mixin.
/// @author Soledge (https://github.com/vectorized/soledge/blob/main/src/utils/ReentrancyGuard.sol)
///
/// Note: As soon as Solidity supports TSTORE,
/// this file will be updated with a TSTORE mode.
abstract contract ReentrancyGuard {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to: `uint72(bytes9(keccak256("_REENTRANCY_GUARD_SLOT")))`.
    /// Large enough to avoid collisions with lower slots,
    /// but not too large to prevent bytecode bloat.
    uint256 private constant _REENTRANCY_GUARD_SLOT = 0x929eee149b4bd21268;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      REENTRANCY GUARD                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    modifier nonReentrant() virtual {
        assembly ("memory-safe") {
            if eq(sload(_REENTRANCY_GUARD_SLOT), 2) { revert(codesize(), 0x00) }
            sstore(_REENTRANCY_GUARD_SLOT, 2)
        }
        _;
        assembly ("memory-safe") {
            sstore(_REENTRANCY_GUARD_SLOT, 1)
        }
    }
}
