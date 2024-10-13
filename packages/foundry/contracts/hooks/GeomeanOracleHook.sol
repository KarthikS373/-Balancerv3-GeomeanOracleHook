// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import { IHooks } from "@balancer-labs/v3-interfaces/contracts/vault/IHooks.sol";
import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";
import {
    HookFlags,
    AfterSwapParams,
    PoolSwapParams,
    TokenConfig,
    LiquidityManagement
} from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import { BaseHooks } from "@balancer-labs/v3-vault/contracts/BaseHooks.sol";
import { VaultGuard } from "@balancer-labs/v3-vault/contracts/VaultGuard.sol";

import { IGeomeanOracleHook } from "./interface/IGeomeanOracleHook.sol";
import { GeomeanLibrary } from "./libraries/GeomeanLibrary.sol";

/**
 * @title GeomeanOracleHook
 * @notice A hook that turns a Balancer pool into a Geomean Oracle by tracking price observations
 */
contract GeomeanOracleHook is IGeomeanOracleHook, BaseHooks, VaultGuard {
    using GeomeanLibrary for uint256[];

    // Allowed factory to prevent unauthorized pool registrations
    address public immutable allowedFactory;
    // Maximum number of observations to store per pool
    uint256 public constant MAX_OBSERVATIONS = 100;
    // Structure to store observations
    struct Observation {
        uint32 timestamp;
        uint256 price;
    }
    // Mapping from pool ID to its observations
    mapping(address => Observation[]) public poolObservations;

    // Event emitted when the hook is registered to a pool
    event GeomeanOracleHookRegistered(address indexed hook, address indexed factory, address indexed pool);
    // Event emitted when a new observation is recorded
    event ObservationRecorded(address indexed pool, uint256 price, uint32 timestamp);
    // Event emitted when the allowed factory is updated (if mutable)
    event AllowedFactoryUpdated(address indexed oldFactory, address indexed newFactory);

    // Errors
    error UnauthorizedFactory(address factory);
    error UnsupportedPoolTokens(uint256 tokenCount);
    error ZeroPriceObserved();
    error OverflowInGeomeanCalculation();
    error InvalidPoolConfiguration();

    /**
     * @notice Constructor to set the allowed factory
     * @param vault The Balancer Vault address
     * @param _allowedFactory The factory allowed to register pools with this hook
     */
    constructor(IVault vault, address _allowedFactory) VaultGuard(vault) BaseHooks() {
        require(_allowedFactory != address(0), "GeomeanOracleHook: Factory address cannot be zero");
        allowedFactory = _allowedFactory;
    }

    /**
     * @inheritdoc IHooks
     */
    function onRegister(
        address factory,
        address pool,
        TokenConfig[] memory,
        LiquidityManagement calldata
    ) public override(BaseHooks, IHooks) onlyVault returns (bool) {
        if (factory != allowedFactory) {
            revert UnauthorizedFactory(factory);
        }

        // Emit registration event
        emit GeomeanOracleHookRegistered(address(this), factory, pool);

        // Additional pool configuration to be added here
        // For example, ensuring the pool has exactly two tokens
        // and that it supports the required hook flags
        if (_vault.getPoolTokens(pool).length != 2) {
            revert UnsupportedPoolTokens(_vault.getPoolTokens(pool).length);
        }

        return true;
    }

    /**
     * @inheritdoc IHooks
     */
    function getHookFlags() public pure override(BaseHooks, IHooks) returns (HookFlags memory hookFlags) {
        hookFlags.shouldCallAfterSwap = true;
        return hookFlags;
    }

    function onAfterSwap(
        AfterSwapParams calldata params,
        address pool,
        uint256 staticSwapFeePercentage
    ) external onlyVault returns (bool, uint256) {
        // Ensure the pool has exactly two tokens for simplicity
        uint256 tokenCount = _vault.getPoolTokens(pool).length;
        if (tokenCount != 2) {
            revert UnsupportedPoolTokens(tokenCount);
        }

        // Calculate price for token1 / token0 (Assuming token0 is the base and token1 is the quote)
        uint256 price;
        if (params.amountInScaled18 > 0) {
            price = (params.amountOutScaled18 * 1e18) / params.amountInScaled18;
        } else {
            revert ZeroPriceObserved();
        }

        // Record the observation
        _recordObservation(pool, price);

        // Do not modify the swap fee
        return (true, staticSwapFeePercentage);
    }

    /**
     * @inheritdoc IGeomeanOracleHook
     */
    function getGeomeanPrice(address pool) external view override returns (uint256 geomeanPrice) {
        Observation[] storage obs = poolObservations[pool];

        require(obs.length > 0, "GeomeanOracleHook: No observations available");

        uint256[] memory prices = new uint256[](obs.length);
        for (uint256 i = 0; i < obs.length; i++) {
            prices[i] = obs[i].price;
        }

        geomeanPrice = prices.geomean();
    }

    /**
     * @notice Records a new price observation for the pool.
     * @param pool The pool address.
     * @param price The current price.
     */
    function _recordObservation(address pool, uint256 price) internal {
        Observation[] storage obs = poolObservations[pool];

        require(price > 0, "GeomeanOracleHook: Price must be greater than zero");

        // Append new observation
        obs.push(Observation({ timestamp: uint32(block.timestamp), price: price }));

        // Ensure the number of observations does not exceed the maximum
        if (obs.length > MAX_OBSERVATIONS) {
            for (uint256 i = 1; i < obs.length; i++) {
                obs[i - 1] = obs[i];
            }
            obs.pop();
        }

        emit ObservationRecorded(pool, price, uint32(block.timestamp));
    }
}
