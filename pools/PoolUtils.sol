pragma solidity =0.8.20;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../openzeppelin/utils/math/Math.sol";
import "./interfaces/IPools.sol";


library PoolUtils
	{
	using SafeERC20 for IERC20;

	// Token balances less than dust are treated as if they don't exist at all.
	// With the 18 decimals that are used for most tokens, DUST has a value of 0.0000000000000001
	// For tokens with 6 decimal places (like USDC) DUST has a value of .0001
	uint256 constant public _DUST = 100;


    // Return the unique poolID for the given two tokens.
    // Tokens are sorted before being hashed to make reversed pairs equivalent.
    // flipped = address(tokenB) < address(tokenA)
    function poolID( IERC20 tokenA, IERC20 tokenB ) internal pure returns (bytes32 _poolID, bool _flipped)
    	{
        // See if the token orders are flipped
        if ( uint160(address(tokenB)) < uint160(address(tokenA)) )
            return (keccak256(abi.encodePacked(address(tokenB), address(tokenA))), true);

        return (keccak256(abi.encodePacked(address(tokenA), address(tokenB))), false);
    	}


	// Determine the expected swap result for a given series of swaps and amountIn
	function quoteAmountOut( IPools pools, IERC20[] memory tokens, uint256 amountIn ) internal view returns (uint256 amountOut)
		{
		require( tokens.length >= 2, "Must have at least two tokens swapped" );

		IERC20 tokenIn = tokens[0];
		IERC20 tokenOut;

		for( uint256 i = 1; i < tokens.length; i++ )
			{
			tokenOut = tokens[i];

			(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(tokenIn, tokenOut);

			if ( reserve0 <= _DUST || reserve1 <= _DUST || amountIn <= _DUST )
				return 0;

			uint256 k = reserve0 * reserve1;

			// Determine amountOut based on amountIn and the reserves
			reserve0 += amountIn;
			amountOut = reserve1 - k / reserve0;

			tokenIn = tokenOut;
			amountIn = amountOut;
			}

		return amountOut;
		}


	// For a given desired amountOut and a series of swaps, determine the amountIn that would be required.
	// amountIn is rounded up
	function quoteAmountIn(  IPools pools, IERC20[] memory tokens, uint256 amountOut ) internal view returns (uint256 amountIn)
		{
		require( tokens.length >= 2, "Must have at least two tokens swapped" );

		IERC20 tokenOut = tokens[ tokens.length - 1 ];
		IERC20 tokenIn;

		for( uint256 i = 2; i <= tokens.length; i++ )
			{
			tokenIn = tokens[ tokens.length - i];

			(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(tokenIn, tokenOut);

			if ( reserve0 <= _DUST || reserve1 <= _DUST || amountOut >= reserve1 || amountOut < _DUST)
				return 0;

			uint256 k = reserve0 * reserve1;

			// Determine amountIn based on amountOut and the reserves
			// Round up here to err on the side of caution
			amountIn = Math.ceilDiv( k, reserve1 - amountOut ) - reserve0;

			tokenOut = tokenIn;
			amountOut = amountIn;
			}

		return amountIn;
		}
	}
