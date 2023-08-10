// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/utils/math/Math.sol";
import "../abdk/ABDKMathQuad.sol";
import "../openzeppelin/token/ERC20/IERC20.sol";
import "./PoolUtils.sol";
import "./interfaces/IPoolStats.sol";


contract PoolStats is IPoolStats
	{
	uint256 constant public MOVING_AVERAGE_PERIOD = 30 minutes;

	bytes16 immutable public ZERO = ABDKMathQuad.fromUInt(0);
	bytes16 immutable public ONE = ABDKMathQuad.fromUInt(1);

	// The exponential average alpha = 2 / (MOVING_AVERAGE_PERIOD + 1)
	bytes16 immutable public alpha = ABDKMathQuad.div( ABDKMathQuad.fromUInt(2),  ABDKMathQuad.fromUInt(MOVING_AVERAGE_PERIOD + 1) );

	// The last time stats were updated for a pool
	mapping(bytes32=>uint256) public lastUpdateTimes;

	// The exponential averages for pools of reserve0 / reserve1
	// Stored as ABDKMathQuad
	mapping(bytes32=>bytes16) public averageReserveRatios;

	// The profits (in WETH) that were contributed by each pool as arbitrage profits since the last performUpkeep was called.
	mapping(bytes32=>uint256) public profitsForPools;


	// Update the exponential moving average of the pool reserve ratios for the given pool that was just involved in a direct swap.
	// Reserve ratio stored as reserve0 / reserve1
	function _updatePoolStats( bytes32 poolID, uint256 reserve0, uint256 reserve1 ) internal
		{
		// Update the exponential average
		bytes16 reserveRatio = ABDKMathQuad.div( ABDKMathQuad.fromUInt(reserve0), ABDKMathQuad.fromUInt(reserve1) );

		// Use a novel mechanism to compute the exponential average with irregular periods between data points.
		// Simulation shows that this works quite well and is well correlated to a traditional EMA with a similar uniform period.
		uint256 timeSinceLastUpdate = block.timestamp - lastUpdateTimes[poolID];
		bytes16 effectiveAlpha = ABDKMathQuad.mul( ABDKMathQuad.fromUInt(timeSinceLastUpdate), alpha );

		// Make sure effectiveAlpha doesn't exceed 1
		if ( ABDKMathQuad.cmp( effectiveAlpha, ONE ) == 1 )
			effectiveAlpha = ONE;

		// If zero previous average then just use the full reserveRatio
		if ( ABDKMathQuad.eq( averageReserveRatios[poolID], ZERO ) )
			effectiveAlpha = ONE;

		// exponentialAverage = exponentialAverage * (1 - alpha) +  reserveRatio * alpha
		bytes16 left = ABDKMathQuad.mul( averageReserveRatios[poolID], ABDKMathQuad.sub(ONE, effectiveAlpha));
		bytes16 right = ABDKMathQuad.mul( reserveRatio, effectiveAlpha);

		averageReserveRatios[poolID] = ABDKMathQuad.add(left, right);

		// Adjust the last update time for the pool
		lastUpdateTimes[poolID] = block.timestamp;
		}


	// Keep track of the which pools contributed to a recent arbitrage profit so that they can be rewarded later on performUpkeep.
	function _updateProfitsFromArbitrage( bool isWhitelistedPair, IERC20 arbToken2, IERC20 arbToken3, IERC20 wbtc, uint256 arbitrageProfit ) internal
		{
		if ( arbitrageProfit == 0 )
			return;

		if ( isWhitelistedPair )
			{
			// The arb cycle was: WETH->arbToken2->arbToken3->WETH
			// Pools rewarded on performUpkeep: WETH/arbToken2, arbToken2/arbToken3, WETH/arbToken3
			(bytes32 poolID,) = PoolUtils.poolID( arbToken2, arbToken3 );

			profitsForPools[poolID] += arbitrageProfit;
			}
		else
			{
			// The arb cycle was: WETH->arbToken2->wbtc->arbToken3->WETH
			// Pools rewarded on performUpkeep: WETH/arbToken2, WETH/arbToken3, WBTC/arbToken2, , WBTC/arbToken3, WBTC/WETH
			(bytes32 poolID,) = PoolUtils.poolID( arbToken2, wbtc );
			profitsForPools[poolID] += arbitrageProfit;

			(poolID,) = PoolUtils.poolID( arbToken3, wbtc );
			profitsForPools[poolID] += arbitrageProfit;
			}
		}


	// === VIEWS ===

	// The 30 minute exponential average of the reserve ratios: reserveA / reserveB
	function averageReserveRatio( IERC20 tokenA, IERC20 tokenB ) public view returns (bytes16 averageRatio)
		{
		(bytes32 poolID, bool flipped) = PoolUtils.poolID(tokenA, tokenB);

		averageRatio = averageReserveRatios[poolID];
		if ( ABDKMathQuad.eq( averageRatio, ZERO ) )
			return ZERO;

		// If the provided tokens are flipped, then we need to flip the ratio as well
		if ( flipped )
			averageRatio = ABDKMathQuad.div( ONE, averageRatio );
		}
	}