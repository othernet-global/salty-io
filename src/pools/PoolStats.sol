// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./PoolUtils.sol";
import "./interfaces/IPoolStats.sol";
import "../interfaces/IExchangeConfig.sol";


// Keeps track of the arbitrage profits generated by pools (for proportional rewards distribution) and lastSwapTimestamps.
contract PoolStats is IPoolStats
	{
	IExchangeConfig public exchangeConfig;

	// The last timestamps that a pool was involved in a swap.
	// Used to prevent same block manipulation of counterswaps
	mapping(bytes32=>uint256) public _lastSwapTimestamps;

	// The profits (in WETH) that were contributed by each pool as arbitrage profits since the last performUpkeep was called.
	// Used to divide rewards proportionally amongst pools based on contributed arbitrage profits
	mapping(bytes32=>uint256) public _profitsForPools;


    constructor( IExchangeConfig _exchangeConfig )
    	{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		exchangeConfig = _exchangeConfig;
    	}


	// Keep track of the which pools contributed to a recent arbitrage profit so that they can be rewarded later on performUpkeep.
	function _updateProfitsFromArbitrage( bool isWhitelistedPair, IERC20 arbToken2, IERC20 arbToken3, IERC20 wbtc, IERC20 weth, uint256 arbitrageProfit ) internal
		{
		if ( arbitrageProfit == 0 )
			return;

		if ( isWhitelistedPair )
			{
			// Divide the profit evenly across the 3 pools that took part in the arbitrage
			arbitrageProfit = arbitrageProfit / 3;

			// The arb cycle was: WETH->arbToken2->arbToken3->WETH
			(bytes32 poolID,) = PoolUtils._poolID( weth, arbToken2 );
			_profitsForPools[poolID] += arbitrageProfit;

			(poolID,) = PoolUtils._poolID( arbToken2, arbToken3 );
			_profitsForPools[poolID] += arbitrageProfit;

			(poolID,) = PoolUtils._poolID( arbToken3, weth );
			_profitsForPools[poolID] += arbitrageProfit;
			}
		else
			{
			// Divide the profit evenly across the 4 pools that took part in the arbitrage
			arbitrageProfit = arbitrageProfit / 4;

			// The arb cycle was: WETH->arbToken2->wbtc->arbToken3->WETH
			(bytes32 poolID,) = PoolUtils._poolID( weth, arbToken2 );
			_profitsForPools[poolID] += arbitrageProfit;

			(poolID,) = PoolUtils._poolID( arbToken2, wbtc );
			_profitsForPools[poolID] += arbitrageProfit;

			(poolID,) = PoolUtils._poolID( wbtc, arbToken3 );
			_profitsForPools[poolID] += arbitrageProfit;

			(poolID,) = PoolUtils._poolID( arbToken3, weth );
			_profitsForPools[poolID] += arbitrageProfit;
			}
		}


	function clearProfitsForPools( bytes32[] memory poolIDs ) public
		{
		require(msg.sender == address(exchangeConfig.upkeep()), "PoolStats.clearProfitsForPools is only callable from the Upkeep contract" );

		for( uint256 i = 0; i < poolIDs.length; i++ )
			_profitsForPools[ poolIDs[i] ] = 0;
		}


	// === VIEWS ===

	function lastSwapTimestamp( bytes32 poolID ) public view returns (uint256 _lastSwapTimestamp)
		{
		return _lastSwapTimestamps[poolID];
		}


	function profitsForPools( bytes32[] memory poolIDs ) public view returns (uint256[] memory _profits)
		{
		_profits = new uint256[](poolIDs.length);

		for( uint256 i = 0; i < poolIDs.length; i++ )
			_profits[i] = _profitsForPools[ poolIDs[i] ];
		}
	}