// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "./interfaces/IPools.sol";
import "../openzeppelin/utils/math/Math.sol";
import "../abdk/ABDKMathQuad.sol";


contract PoolStats
	{
	uint256 constant public MOVING_AVERAGE_PERIOD = 30 minutes;

	// Token reserves less than dust are treated as if they don't exist at all.
	// With the 18 decimals that are used for most tokens, DUST has a value of 0.0000000000000001
	// For tokens with 6 decimal places (like USDC) DUST has a value of .0001
	uint256 constant public DUST = 100;

	bytes16 immutable public ONE;
	bytes16 immutable public ZERO;

	// The default alpha for the exponential average
	bytes16 immutable public alpha;


	// The last time stats were updated for a pool
	mapping(bytes32=>uint256) public lastUpdateTimes;

	// The exponential averages for pools of reserve0 / reserve1
	// Stored as ABDKMathQuad
	mapping(bytes32=>bytes16) public averageReserveRatios;


	constructor()
		{
		// The exponential average alpha = 2 / (MOVING_AVERAGE_PERIOD + 1)
		alpha = ABDKMathQuad.div( ABDKMathQuad.fromUInt(2),  ABDKMathQuad.fromUInt(MOVING_AVERAGE_PERIOD + 1) );
		ONE = ABDKMathQuad.fromUInt(1);
		ZERO = ABDKMathQuad.fromUInt(0);
		}


	// Update the exponential moving average of the pool reserve ratios for the given pool that was just involved in a direct swap.
	// Only direct swaps update the stats as arbitrage would requires too many updates and increase gas costs prohibitively.
	// Reserve ratio stored as reserve0 / reserve1
	function _updatePoolStats( bytes32 poolID, uint256 reserve0, uint256 reserve1 ) internal
		{
		// Update the exponential average
		bytes16 reserveRatio = ABDKMathQuad.div( ABDKMathQuad.fromUInt(reserve0), ABDKMathQuad.fromUInt(reserve1) );

		// Use a novel mechanism to compute the exponential average with irregular periods between data points.
		// Simulation shows that this works quite well and is well correlated to a traditional EMA with a similar period.
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

		// Adjust the last swap time for the pool - not updated for swaps that use available direct buffers above.
		lastUpdateTimes[poolID] = block.timestamp;
		}
	}