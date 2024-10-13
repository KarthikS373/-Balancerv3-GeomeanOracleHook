// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import { IHooks } from "@balancer-labs/v3-interfaces/contracts/vault/IHooks.sol";

/**
 * @title IGeomeanOracleHook
 * @notice Interface for the Geomean Oracle Hook.
 */
interface IGeomeanOracleHook is IHooks {
    /**
     * @notice Returns the geometric mean price for a given pool.
     * @param pool The pool address.
     * @return geomeanPrice The geometric mean price.
     */
    function getGeomeanPrice(address pool) external view returns (uint256 geomeanPrice);
}
