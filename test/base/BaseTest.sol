// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.4;

import "forge-std/Test.sol";

contract BaseTest is Test {
    uint256 private constant RAY = 10 ** 27;

    bytes constant ARITHMETIC_ERROR = abi.encodeWithSignature("Panic(uint256)", 0x11);
    bytes constant ZERO_DIVISION = abi.encodeWithSignature("Panic(uint256)", 0x12);

    function getDiff(uint256 x, uint256 y) internal pure returns (uint256 diff) {
        diff = x > y ? x - y : y - x;
    }

    function assertWithinPrecision(uint256 x, uint256 y, uint256 accuracy) internal {
        assertWithinPrecision(x, y, accuracy, "");
    }

    // Verify equality within accuracy decimals
    function assertWithinPrecision(uint256 x, uint256 y, uint256 accuracy, string memory err) internal {
        uint256 diff = getDiff(x, y);

        if (diff == 0) return;

        uint256 denominator = x == 0 ? y : x;

        if (((diff * RAY) / denominator) < (RAY / 10 ** accuracy)) return;

        if (bytes(err).length > 0) emit log_named_string("Error", err);

        emit log_named_uint("Error: approx a == b not satisfied, accuracy digits", accuracy);

        emit log_named_uint("  Expected", y);
        emit log_named_uint("    Actual", x);

        fail();
    }

    function assertWithinPercentage(uint256 x, uint256 y, uint256 percentage) internal {
        assertWithinPercentage(x, y, percentage, "");
    }

    // Verify equality within accuracy percentage (basis points)
    function assertWithinPercentage(uint256 x, uint256 y, uint256 percentage, string memory err) internal {
        uint256 diff = getDiff(x, y);

        if (diff == 0) return;

        uint256 denominator = x == 0 ? y : x;

        if (((diff * RAY) / denominator) < percentage * RAY / 10_000) return;

        if (bytes(err).length > 0) emit log_named_string("Error", err);

        emit log_named_uint("Error: approx a == b not satisfied, accuracy digits", percentage);

        emit log_named_uint("  Expected", y);
        emit log_named_uint("    Actual", x);

        fail();
    }

    function assertWithinDiff(uint256 x, uint256 y, uint256 diff) internal {
        assertWithinDiff(x, y, diff, "");
    }

    // Verify equality within difference
    function assertWithinDiff(uint256 x, uint256 y, uint256 expectedDiff, string memory err) internal {
        if (getDiff(x, y) <= expectedDiff) return;

        if (bytes(err).length > 0) emit log_named_string("Error", err);

        emit log_named_uint("Error: approx a == b not satisfied, accuracy digits", expectedDiff);

        emit log_named_uint("  Expected", y);
        emit log_named_uint("    Actual", x);

        fail();
    }

    // Constrict values to a range, inclusive of min and max values.
    function constrictToRange(uint256 x, uint256 min, uint256 max) internal pure returns (uint256 result) {
        require(max >= min, "MAX_LESS_THAN_MIN");

        if (min == max) return min; // A range of 0 is effectively a single value.

        if (x >= min && x <= max) return x; // Use value directly from fuzz if already in range.

        if (min == 0 && max == type(uint256).max) return x; // The entire uint256 space is effectively x.

        return (x % ((max - min) + 1)) + min; // Given the above exit conditions, `(max - min) + 1 <= type(uint256).max`.
    }

    // Adapted from https://stackoverflow.com/questions/47129173/how-to-convert-uint-to-string-in-solidity
    function convertUintToString(uint256 input_) internal pure returns (string memory output_) {
        if (input_ == 0) return "0";

        uint256 j = input_;
        uint256 length;

        while (j != 0) {
            length++;
            j /= 10;
        }

        bytes memory output = new bytes(length);
        uint256 k = length;

        while (input_ != 0) {
            k = k - 1;

            uint8 temp = (48 + uint8(input_ - input_ / 10 * 10));
            bytes1 b1 = bytes1(temp);

            output[k] = b1;
            input_ /= 10;
        }

        return string(output);
    }
}

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // computes the hash of a permit
    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }
}
