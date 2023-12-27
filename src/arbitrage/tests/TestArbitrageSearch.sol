// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/IExchangeConfig.sol";
import "../../pools/PoolUtils.sol";
import "../ArbitrageSearch.sol";


contract TestArbitrageSearch is ArbitrageSearch
    {
    constructor( IExchangeConfig _exchangeConfig )
    ArbitrageSearch(_exchangeConfig)
    	{
    	}

	function arbitragePath( IERC20 swapTokenIn, IERC20 swapTokenOut ) public view returns (IERC20 arbToken2, IERC20 arbToken3)
		{
		return _arbitragePath(swapTokenIn, swapTokenOut );
		}


	// Perform a modified binary search to search for the bestArbAmountIn in a range of 1% to 125% of swapAmountInValueInETH.
	// The search will be done using a binary search algorithm where profits are determined at the midpoint of the current range, and also just to the right of the midpoint.
	// Assuming that the profit function is unimodal (which may not actually be true), the two profit calculations at and near the midpoint can show us which half of the range the maximum profit is in.
	function bisectionSearch( uint256 swapAmountInValueInETH, uint256 reservesA0, uint256 reservesA1, uint256 reservesB0, uint256 reservesB1, uint256 reservesC0, uint256 reservesC1 ) public pure returns (uint256 bestArbAmountIn)
		{
		return _bisectionSearch( swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1 );
		}
	}

