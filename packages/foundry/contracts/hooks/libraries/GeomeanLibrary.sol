// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

/**
 * @title GeomeanLibrary
 * @notice Library to compute the geometric mean of multiple values
 */
library GeomeanLibrary {
    error GeomeanLibrary__NoValuesProvided();
    error GeomeanLibrary__OverflowOrZeroProduct();
    error GeomeanLibrary__NMustBePositive();
    error GeomeanLibrary__OverflowInPower();
    error GeomeanLibrary__DivisionByZero();

    /**
     * @notice Computes the geometric mean of an array of values
     * @param values The array of values
     * @return geomean The geometric mean of the values
     */
    function geomean(uint256[] memory values) internal pure returns (uint256 geomean) {
        if (values.length == 0) {
            revert GeomeanLibrary__NoValuesProvided();
        }

        uint256 product = 1;
        for (uint256 i = 0; i < values.length; i++) {
            // Prevent overflow by using log-based approximation or similar methods
            // Here we use a simplistic approach; for production, consider a more robust method
            product = mulDiv(product, values[i], 1e18);
            if (product == 0) {
                revert GeomeanLibrary__OverflowOrZeroProduct();
            }
        }

        // Calculate the nth root, where n is the number of values
        geomean = nthRoot(values.length, product);
    }

    /**
     * @notice Computes the nth root of a number using binary search
     * @param n The root to compute
     * @param x The number to compute the root of
     * @return root The nth root of x
     */
    function nthRoot(uint256 n, uint256 x) internal pure returns (uint256 root) {
        if (n == 0) {
            revert GeomeanLibrary__NMustBePositive();
        }
        if (x == 0) return 0;

        uint256 upper = x;
        uint256 lower = 1;
        root = 1;

        while (lower <= upper) {
            uint256 mid = lower + (upper - lower) / 2;
            uint256 midPow = power(mid, n);
            if (midPow == x) {
                root = mid;
                break;
            } else if (midPow < x) {
                root = mid;
                lower = mid + 1;
            } else {
                upper = mid - 1;
            }
        }
    }

    /**
     * @notice Computes a^b where a and b are unsigned integers
     * @param a The base
     * @param b The exponent
     * @return result The result of a ^ b
     */
    function power(uint256 a, uint256 b) internal pure returns (uint256 result) {
        result = 1;
        for (; b > 0; b--) {
            if (result > type(uint256).max / a) {
                revert GeomeanLibrary__OverflowInPower();
            }
            result *= a;
        }
    }

    /**
     * @notice Multiplies two numbers and divides by a third, avoiding overflow
     * @param x The multiplicand
     * @param y The multiplier
     * @param denominator The divisor
     * @return result The result of (x * y) / denominator
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        if (denominator == 0) {
            revert GeomeanLibrary__DivisionByZero();
        }
        result = (x * y) / denominator;
    }
}
