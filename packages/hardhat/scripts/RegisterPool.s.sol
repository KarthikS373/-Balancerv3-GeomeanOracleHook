// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 } from "../contracts/interfaces/IVaultExtension.sol";
import { LiquidityManagement, IRateProvider, PoolHooks, TokenConfig, TokenType } from "../contracts/interfaces/VaultTypes.sol";
import {TestAddresses} from "../test/utils/TestAddresses.sol";
// import {TestAddresses} from  "packages/hardhat/test/utils/TestAddresses.sol";

/**
 * TODO - Steve, move this blob of comments to the PR once I make a dev branch, and a feature branch and a PR to fix the deployment script onto said dev branch.
 * TODO - where I left off STEVE --> I gotta debug the dependencies / mappings cause I'm trying to use TestAddresses.sol (a new contract I made to make things cleaner) Ultimately though, I just need to test if IVault(vaultAddress).registerPool() works instead of calling IVaultExtension.registerPool()
 * 
 * Register an already deployed pool on sepolia
 *
 * balancer docs
 * https://docs-v3.balancer.fi/concepts/vault/onchain-api.html#registerpool
 *
 * registerPool function
 * https://github.com/balancer/balancer-v3-monorepo/blob/2ad8501c85e8afb2f25d970344af700a571b1d0b/pkg/vault/contracts/VaultExtension.sol#L130-L149
 *
 * VaultTypes (TokenType, TokenConfig, IRateProvider)
 * https://github.com/balancer/balancer-v3-monorepo/blob/main/pkg/interfaces/contracts/vault/VaultTypes.sol
 */

/**
 * @title RegisterPool Script
 * @author BUIDL GUIDL (placeholder)
 * @notice The script registers a pool with the BalancerV3 Vault on sepolia 
 * @dev This is in the early WIP stage, so we are working with already deployed pools for now. See PR # for context on related docs, code blobs, etc.
 */
contract RegisterPool is TestAddresses, Script {
	// IVaultExtension constant vaultExtension =
	// 	IVaultExtension(0x718e1176f01dDBb2409A77B2847B749c8dF4457f);

	// address sepoliaDAI = 0xB77EB1A70A96fDAAeB31DB1b42F2b8b5846b2613;
	// address sepoliaUSDC = 0x80D6d3946ed8A1Da4E226aa21CCdDc32bd127d1A;

	function run() external {
		uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
		vm.startBroadcast(deployerPrivateKey);

		/// args for registerPool
		address pool = address(0); // Address of pool to register NOTE - this pool is already registered, so you need to replace it or else the script will revert.

		TokenConfig[] memory tokenConfig = new TokenConfig[](2); // An array of descriptors for the tokens the pool will manage.

		// make sure to have proper token order (alphanumeric)
		tokenConfig[0] = TokenConfig({
			token: IERC20(sepoliaUSDC),
			tokenType: TokenType.STANDARD,
			rateProvider: IRateProvider(address(0)),
			yieldFeeExempt: false
		});
		tokenConfig[1] = TokenConfig({
			token: IERC20(sepoliaDAI),
			tokenType: TokenType.STANDARD,
			rateProvider: IRateProvider(address(0)),
			yieldFeeExempt: false
		});
		uint256 pauseWindowEndTime = 0; // The timestamp after which it is no longer possible to pause the pool

		address pauseManager = address(0); // Optional contract the Vault will allow to pause the pool

		PoolHooks memory hookConfig = PoolHooks({
			shouldCallBeforeInitialize: false,
			shouldCallAfterInitialize: false,
			shouldCallBeforeSwap: false,
			shouldCallAfterSwap: false,
			shouldCallBeforeAddLiquidity: false,
			shouldCallAfterAddLiquidity: false,
			shouldCallBeforeRemoveLiquidity: false,
			shouldCallAfterRemoveLiquidity: false
		}); // Flags indicating which hooks the pool supports

		LiquidityManagement memory liquidityManagement = LiquidityManagement({
			supportsAddLiquidityCustom: false,
			supportsRemoveLiquidityCustom: false
		}); // Liquidity management flags with implemented methods

		/// send register tx 
		vault.registerPool(
			pool,
			tokenConfig,
			pauseWindowEndTime,
			pauseManager,
			hookConfig,
			liquidityManagement
		);

		vm.stopBroadcast();
	}
}
