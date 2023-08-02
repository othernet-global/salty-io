// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "./interfaces/IDAOConfig.sol";
import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../price_feed/interfaces/IPriceAggregator.sol";


// Performs upkeep on the exchange:
// 1. Withdraws the WETH deposited in the Pools contract (from previous automatic arbitrage).
// 2. Updates the prices of BTC and ETH in the PriceAggregator.
// 3. Converts a default 70% of WETH to SALT and sends it to the relevant RewardsEmitters.
// 4. Sends a default 5% of the remaining WETH to the caller of performUpkeep()
// 5. Uses the remaining WETH in the contract to form the highest yield POL - choosing from the SALT/WBTC, SALT/WETH and SALT/USDS pools.
// 6. Calls ArbitrageProfits.clearProfitsForPools (which was used in the above step).
// 7. Sends SALT Emissions to the staking and liquidity RewardsEmitters.
// 8. Distributes SALT from the staking, liquidity and collateral RewardsEmitters.
// 9. Sells liquidated WBTC and WETH to burn the required amount of USDS from liquidated positions.
// 10. Collects SALT rewards from Protocol Owned Liquidity (SALT/WBTC, SALT/WETH or SALT/USDS): burns 45% and sends 10% to the team.
// 11. Releases SALT from the DAO vesting wallet (linear distribution over 10 years).
// 12. Releases SALT from the team vesting wallet (linear distribution over 10 years).


contract UpkeepPerformer
    {
    event UpkeepError(string description, bytes error);

	uint256 public lastUpkeepTime;


    constructor()
		{
		lastUpkeepTime = block.timestamp;
		}


	// 1. Withdraw the WETH deposited in the Pools contract (from previous automatic arbitrage).
	function _step1( IPools pools ) internal
		{
 		try pools.performUpkeep() {}
		catch (bytes memory error) { emit UpkeepError("Step 1", error); }
		}


	// 2. Update the prices of BTC and ETH in the PriceAggregator.
	function _step2( IPriceAggregator priceAggregator ) internal
		{
 		try priceAggregator.performUpkeep() {}
		catch (bytes memory error) { emit UpkeepError("Step 2", error); }
		}


	// 3. Swap a default 70% of withdrawn WETH to SALT and send it to the relevant RewardsEmitters based on how much each pool contributed to the generated profit.
	function _step3( IERC20 weth, IDAOConfig daoConfig ) internal
		{
		uint256 wethBalance = weth.balanceOf( address(this) );
		uint256 wethToSwap = wethBalance * daoConfig.daoArbitragePercent() / 100;

		// Send rewards to WBTC/WBTC liquidity providers first

		}


	function _performUpkeep( IPools pools, IPriceAggregator priceAggregator, IExchangeConfig exchangeConfig, IPoolsConfig poolsConfig, IDAOConfig daoConfig ) internal
		{
		uint256 timeSinceLastUpkeep = block.timestamp - lastUpkeepTime;

		IERC20 weth = exchangeConfig.weth();
		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();

		// Perform the multiple perform upkeep steps.
		// Try/catch blocks are used within each one so that if any of the steps reverts it won't halt the rest of the upkeep.
		// Upkeep steps do not require the previous steps in the process are successful.

		_step1(pools);
		_step2(priceAggregator);
		_step3(weth, daoConfig);

//		clear profitsForPools

		lastUpkeepTime = block.timestamp;
		}
	}
