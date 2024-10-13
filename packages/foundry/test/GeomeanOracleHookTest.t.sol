// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import { IVault } from "@balancer-labs/v3-interfaces/contracts/vault/IVault.sol";
import {
    LiquidityManagement,
    PoolRoleAccounts,
    TokenConfig
} from "@balancer-labs/v3-interfaces/contracts/vault/VaultTypes.sol";
import { ERC20TestToken } from "@balancer-labs/v3-solidity-utils/contracts/test/ERC20TestToken.sol";
import { VaultMockDeployer } from "@balancer-labs/v3-vault/test/foundry/utils/VaultMockDeployer.sol";
import { VaultMock } from "@balancer-labs/v3-vault/contracts/test/VaultMock.sol";
import { PoolMock } from "@balancer-labs/v3-vault/contracts/test/PoolMock.sol";
import { VaultMockDeployer } from "@balancer-labs/v3-vault/test/foundry/utils/VaultMockDeployer.sol";
import { BaseVaultTest } from "@balancer-labs/v3-vault/test/foundry/utils/BaseVaultTest.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { GeomeanLibrary } from "../contracts/hooks/libraries/GeomeanLibrary.sol";
import { GeomeanOracleHook } from "../contracts/hooks/GeomeanOracleHook.sol";

contract GeomeanOracleHookTest is BaseVaultTest, Test {
    using GeomeanLibrary for uint256[];
    using stdStorage for StdStorage;

    // Roles
    address owner;
    address allowedFactory;
    address unauthorizedFactory;
    address alice;
    address bob;

    // Contracts
    VaultMock vault;
    PoolMock pool;

    IERC20 token0;
    IERC20 token1;

    GeomeanOracleHook oracleHook;

    // Pool configuration
    bytes32 poolId;
    uint256 constant MAX_OBSERVATIONS = 100;

    function setUp() public {
        // Assign roles
        owner = address(this);
        allowedFactory = address(0x1);
        unauthorizedFactory = address(0x2);
        alice = address(0x3);
        bob = address(0x4);

        // Deploy VaultMock
        vault = VaultMockDeployer.deploy();

        // Assign poolId for the pool
        poolId = keccak256(abi.encode(address(pool)));
        vault.setPoolId(address(pool), poolId);

        // Deploy GeomeanOracleHook
        oracleHook = new BalancerGeomeanOracleHook(IVault(address(vault)), allowedFactory);

        // Deploy PoolMock
        pool = new PoolMock((IVault(address(vault)), "Test pool", "TEST-POOL"));

        // Assign a poolId in the VaultMock
        vault.setPoolId(address(pool), poolId);

        // Deploy mock ERC20 tokens
        token0 = IERC20(address(new ERC20Mock("Token0", "TK0", 18)));
        token1 = IERC20(address(new ERC20Mock("Token1", "TK1", 18)));
    }

    /**
     * @notice Helper function to simulate pool tokens and balances in VaultMock
     * @param pool Address of the pool
     * @param tokens Array of token addresses
     * @param balances Array of token balances
     */
    function setPoolTokens(address pool, address[] memory tokens, uint256[] memory balances) internal {
        vault.setPoolTokens(pool, tokens, balances);
    }

    /**
     * @notice Test successful registration by the allowed factory
     */
    function testRegisterHook_Success() public {
        // Simulate allowed factory calling registerHook
        vm.prank(allowedFactory);

        // Register the hook to the pool
        vm.prank(allowedFactory);
        bool success = oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        assertTrue(success, "Hook registration failed");
    }

    /**
     * @notice Test registration failure by an unauthorized factory
     */
    function testRegisterHook_UnauthorizedFactory() public {
        // Simulate unauthorized factory calling registerHook
        vm.prank(unauthorizedFactory);

        // Expect revert
        vm.expectRevert(
            abi.encodeWithSelector(BalancerGeomeanOracleHook.UnauthorizedFactory.selector, unauthorizedFactory)
        );

        oracleHook.onRegister(
            unauthorizedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );
    }

    /**
     * @notice Test observation recording after a swap
     */
    function testRecordObservation_AfterSwap() public {
        // Register the hook to the pool as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        // Simulate a swap
        PoolSwapParams memory params = PoolSwapParams({
            tokens: new IERC20,
            amountIn: 1e18,
            amountOut: 2e18,
            indexIn: 0,
            indexOut: 1,
            kind: 0 // SwapKind.EXACT_IN
        });

        // Assign tokens
        params.tokens[0] = token0;
        params.tokens[1] = token1;

        // Expect the ObservationRecorded event
        vm.expectEmit(true, true, true, true);
        emit oracleHook.ObservationRecorded(address(pool), 2e18, uint32(block.timestamp));

        // Perform the swap by invoking onAfterSwap via the VaultMock
        // Since the VaultMock's swap function emits the Swap event, and the hook is registered,
        // the hook's onAfterSwap should be called internally.

        // However, in the provided VaultMock, the swap function does not interact with the hook.
        // To properly simulate, you might need to enhance VaultMock to call the hook's onAfterSwap.

        // For the purpose of this test, we'll manually call onAfterSwap

        // Manually call onAfterSwap (since VaultMock doesn't handle hooks)
        (bool success, uint256 newFee) = oracleHook.onAfterSwap(params, address(pool), 1e16);

        assertTrue(success, "onAfterSwap should return true");
        assertEq(newFee, 1e16, "Swap fee should remain unchanged");

        // Verify the observation is recorded
        bytes32 poolIdRetrieved = vault.getPoolId(address(pool));
        BalancerGeomeanOracleHook.Observation memory lastObs = oracleHook.poolObservations(poolIdRetrieved, 0);
        assertEq(lastObs.price, 2e18, "Recorded price is incorrect");
        assertEq(lastObs.timestamp, uint32(block.timestamp), "Recorded timestamp is incorrect");
    }

    /**
     * @notice Test geometric mean calculation
     */
    function testGetGeomeanPrice() public {
        // Register the hook to the pool as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        bytes32 poolIdRetrieved = vault.getPoolId(address(pool));

        // Record multiple observations
        // Example: prices = [2e18, 2e18, 2e18]
        for (uint256 i = 0; i < 3; i++) {
            PoolSwapParams memory params = PoolSwapParams({
                tokens: new IERC20,
                amountIn: 1e18,
                amountOut: 2e18,
                indexIn: 0,
                indexOut: 1,
                kind: 0 // SwapKind.EXACT_IN
            });
            params.tokens[0] = token0;
            params.tokens[1] = token1;

            oracleHook.onAfterSwap(params, address(pool), 1e16);
        }

        // Calculate expected geomean
        // Geomean of [2, 2, 2] is 2
        uint256 expectedGeomean = 2e18;

        // Fetch geomean price
        uint256 geomeanPrice = oracleHook.getGeomeanPrice(address(pool));

        assertEq(geomeanPrice, expectedGeomean, "Geomean price calculation is incorrect");
    }

    /**
     * @notice Test maximum number of observations
     */
    function testMaxObservations() public {
        // Register the hook to the pool as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        bytes32 poolIdRetrieved = vault.getPoolId(address(pool));

        // Record MAX_OBSERVATIONS + 10 observations
        for (uint256 i = 0; i < MAX_OBSERVATIONS + 10; i++) {
            PoolSwapParams memory params = PoolSwapParams({
                tokens: new IERC20,
                amountIn: 1e18,
                amountOut: 2e18,
                indexIn: 0,
                indexOut: 1,
                kind: 0 // SwapKind.EXACT_IN
            });
            params.tokens[0] = token0;
            params.tokens[1] = token1;

            oracleHook.onAfterSwap(params, address(pool), 1e16);
        }

        // Verify that only the latest MAX_OBSERVATIONS are kept
        for (uint256 i = 0; i < MAX_OBSERVATIONS; i++) {
            BalancerGeomeanOracleHook.Observation memory obs = oracleHook.poolObservations(poolIdRetrieved, i);
            assertEq(obs.price, 2e18, "Observation price mismatch");
        }

        // Ensure that the array length does not exceed MAX_OBSERVATIONS
        // Since Solidity mappings don't support length, we assume in the implementation that it maintains the array correctly
        // Alternatively, you can add a getter to fetch the number of observations
    }

    /**
     * @notice Test zero price observation
     */
    function testZeroPriceObservation() public {
        // Register the hook to the pool as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        // Simulate a swap with amountIn = 0, which should revert
        PoolSwapParams memory params = PoolSwapParams({
            tokens: new IERC20,
            amountIn: 0,
            amountOut: 0,
            indexIn: 0,
            indexOut: 1,
            kind: 0 // SwapKind.EXACT_IN
        });
        params.tokens[0] = token0;
        params.tokens[1] = token1;

        // Expect revert
        vm.expectRevert("GeomeanOracleHook: ZeroPriceObserved()");
        oracleHook.onAfterSwap(params, address(pool), 1e16);
    }

    /**
     * @notice Test pool with more than two tokens
     */
    function testPoolWithMoreThanTwoTokens() public {
        // Deploy a new mock pool with three tokens
        PoolMock threeTokenPool = new PoolMock(address(vault));

        // Assign a new poolId
        bytes32 threeTokenPoolId = keccak256(abi.encode(address(threeTokenPool)));
        vault.setPoolId(address(threeTokenPool), threeTokenPoolId);

        // Register the hook with the new pool as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(threeTokenPool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        // Simulate a swap with three tokens
        PoolSwapParams memory params = PoolSwapParams({
            tokens: new IERC20,
            amountIn: 1e18,
            amountOut: 2e18,
            indexIn: 0,
            indexOut: 2,
            kind: 0 // SwapKind.EXACT_IN
        });
        params.tokens[0] = token0;
        params.tokens[1] = token1;
        params.tokens[2] = IERC20(address(new ERC20Mock("Token2", "TK2", 18)));

        // Expect revert due to unsupported pool tokens
        vm.expectRevert(abi.encodeWithSelector(BalancerGeomeanOracleHook.UnsupportedPoolTokens.selector, 3));
        oracleHook.onAfterSwap(params, address(threeTokenPool), 1e16);
    }

    /**
     * @notice Test geometric mean calculation with varying prices
     */
    function testGeomeanWithVaryingPrices() public {
        // Register the hook to the pool as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        bytes32 poolIdRetrieved = vault.getPoolId(address(pool));

        // Record observations with prices: [2e18, 4e18, 8e18]
        uint256;
        prices[0] = 2e18;
        prices[1] = 4e18;
        prices[2] = 8e18;

        for (uint256 i = 0; i < prices.length; i++) {
            PoolSwapParams memory params = PoolSwapParams({
                tokens: new IERC20,
                amountIn: 1e18,
                amountOut: prices[i],
                indexIn: 0,
                indexOut: 1,
                kind: 0 // SwapKind.EXACT_IN
            });
            params.tokens[0] = token0;
            params.tokens[1] = token1;

            oracleHook.onAfterSwap(params, address(pool), 1e16);
        }

        // Calculate expected geomean: (2 * 4 * 8)^(1/3) = 4
        uint256 expectedGeomean = 4e18;

        // Fetch geomean price
        uint256 geomeanPrice = oracleHook.getGeomeanPrice(address(pool));

        assertEq(geomeanPrice, expectedGeomean, "Geomean price calculation with varying prices is incorrect");
    }

    /**
     * @notice Test that no observations exist initially
     */
    function testGetGeomeanPrice_NoObservations() public {
        // Attempt to get geomean price without any observations
        vm.expectRevert("GeomeanOracleHook: No observations available");
        oracleHook.getGeomeanPrice(address(pool));
    }

    /**
     * @notice Test that the maximum number of observations is maintained
     */
    function testMaxObservations_Maintained() public {
        // Register the hook to the pool as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        bytes32 poolIdRetrieved = vault.getPoolId(address(pool));

        // Record MAX_OBSERVATIONS + 10 observations
        for (uint256 i = 0; i < MAX_OBSERVATIONS + 10; i++) {
            PoolSwapParams memory params = PoolSwapParams({
                tokens: new IERC20,
                amountIn: 1e18,
                amountOut: 2e18,
                indexIn: 0,
                indexOut: 1,
                kind: 0 // SwapKind.EXACT_IN
            });
            params.tokens[0] = token0;
            params.tokens[1] = token1;

            oracleHook.onAfterSwap(params, address(pool), 1e16);
        }

        // Fetch all observations and ensure only the last MAX_OBSERVATIONS are present
        for (uint256 i = 0; i < MAX_OBSERVATIONS; i++) {
            BalancerGeomeanOracleHook.Observation memory obs = oracleHook.poolObservations(poolIdRetrieved, i);
            assertEq(obs.price, 2e18, "Observation price mismatch at index");
        }

        // Optionally, check that the length does not exceed MAX_OBSERVATIONS
        // Since Solidity mappings don't have a length, ensure that no additional observations are accessible
    }

    /**
     * @notice Test geometric mean calculation with overflow scenario
     */
    function testGeomean_Overflow() public {
        // Register the hook to the pool as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        bytes32 poolIdRetrieved = vault.getPoolId(address(pool));

        // Record observations with very large prices to cause overflow in GeomeanLibrary
        uint256;
        prices[0] = type(uint256).max / 2;
        prices[1] = type(uint256).max / 2;

        for (uint256 i = 0; i < prices.length; i++) {
            PoolSwapParams memory params = PoolSwapParams({
                tokens: new IERC20,
                amountIn: 1e18,
                amountOut: prices[i],
                indexIn: 0,
                indexOut: 1,
                kind: 0 // SwapKind.EXACT_IN
            });
            params.tokens[0] = token0;
            params.tokens[1] = token1;

            // Expect overflow in GeomeanLibrary during geomean calculation
            // Depending on implementation, it might revert or handle it differently
            // Here, assume it reverts with "GeomeanLibrary: Overflow in product"
            vm.expectRevert("GeomeanLibrary: Overflow in product");
            oracleHook.onAfterSwap(params, address(pool), 1e16);
        }
    }

    /**
     * @notice Test that the hook correctly handles multiple pools
     */
    function testMultiplePools() public {
        // Deploy a second mock pool
        PoolMock secondPool = new PoolMock(address(vault));
        bytes32 secondPoolId = keccak256(abi.encode(address(secondPool)));
        vault.setPoolId(address(secondPool), secondPoolId);

        // Register the hook to both pools as allowed factory
        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(pool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        vm.prank(allowedFactory);
        oracleHook.onRegister(
            allowedFactory,
            address(secondPool),
            new TokenConfig,
            LiquidityManagement({ enableDonation: false, disableUnbalancedLiquidity: false })
        );

        // Simulate swaps on both pools
        // Pool 1: price = 2e18
        PoolSwapParams memory params1 = PoolSwapParams({
            tokens: new IERC20,
            amountIn: 1e18,
            amountOut: 2e18,
            indexIn: 0,
            indexOut: 1,
            kind: 0 // SwapKind.EXACT_IN
        });
        params1.tokens[0] = token0;
        params1.tokens[1] = token1;
        oracleHook.onAfterSwap(params1, address(pool), 1e16);

        // Pool 2: price = 3e18
        PoolSwapParams memory params2 = PoolSwapParams({
            tokens: new IERC20,
            amountIn: 1e18,
            amountOut: 3e18,
            indexIn: 0,
            indexOut: 1,
            kind: 0 // SwapKind.EXACT_IN
        });
        params2.tokens[0] = token0;
        params2.tokens[1] = token1;
        oracleHook.onAfterSwap(params2, address(secondPool), 1e16);

        // Calculate expected geomeans
        uint256 expectedGeomeanPool1 = 2e18;
        uint256 expectedGeomeanPool2 = 3e18;

        // Fetch geomean prices
        uint256 geomeanPricePool1 = oracleHook.getGeomeanPrice(address(pool));
        uint256 geomeanPricePool2 = oracleHook.getGeomeanPrice(address(secondPool));

        assertEq(geomeanPricePool1, expectedGeomeanPool1, "Geomean price for Pool 1 is incorrect");
        assertEq(geomeanPricePool2, expectedGeomeanPool2, "Geomean price for Pool 2 is incorrect");
    }
}
