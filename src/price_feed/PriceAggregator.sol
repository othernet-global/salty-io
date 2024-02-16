// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./interfaces/IPriceAggregator.sol";
import "./interfaces/IPriceFeed.sol";


// Compares three different price feeds to provide prices for BTC and ETH
// The three price feeds are used so that if one fails to work properly, the other two can still correctly report price (the outlier is discarded).

// The PriceAggregator is simply used for pricing on the website.
// If it needs to be updated, the website itself can be updated to refer to the new contract.
contract PriceAggregator is IPriceAggregator
    {
	IPriceFeed public priceFeed1; // CoreUniswapFeed by default
	IPriceFeed public priceFeed2; // CoreChainlinkFeed by default
	IPriceFeed public priceFeed3; // CoreSaltyFeed by default

	// The maximum percent difference between two non-zero PriceFeed prices when aggregating price.
	// When the two closest PriceFeeds (out of the three) have prices further apart than this the aggregated price is considered invalid.
	uint256 public maximumPriceFeedPercentDifferenceTimes1000 = 3000; // 3.0% with a 1000x multiplier


	constructor( IPriceFeed _priceFeed1, IPriceFeed _priceFeed2, IPriceFeed _priceFeed3 )
		{
		priceFeed1 = _priceFeed1;
		priceFeed2 = _priceFeed2;
		priceFeed3 = _priceFeed3;
		}


	function _absoluteDifference( uint256 x, uint256 y ) internal pure returns (uint256)
		{
		if ( x > y )
			return x - y;

		return y - x;
		}


	function _aggregatePrices( uint256 price1, uint256 price2, uint256 price3 ) internal view returns (uint256)
		{
		uint256 numNonZero;

		if (price1 > 0)
			numNonZero++;

		if (price2 > 0)
			numNonZero++;

		if (price3 > 0)
			numNonZero++;

		// If less than two price sources then return zero to indicate failure
		if ( numNonZero < 2 )
			return 0;

		uint256 diff12 = _absoluteDifference(price1, price2);
		uint256 diff13 = _absoluteDifference(price1, price3);
		uint256 diff23 = _absoluteDifference(price2, price3);

		uint256 priceA;
		uint256 priceB;

		if ( ( diff12 <= diff13 ) && ( diff12 <= diff23 ) )
			(priceA, priceB) = (price1, price2);
		else if ( ( diff13 <= diff12 ) && ( diff13 <= diff23 ) )
			(priceA, priceB) = (price1, price3);
		else if ( ( diff23 <= diff12 ) && ( diff23 <= diff13 ) )
			(priceA, priceB) = (price2, price3);

		uint256 averagePrice = ( priceA + priceB ) / 2;

		// If price sources are too far apart then return zero to indicate failure
		if (  (_absoluteDifference(priceA, priceB) * 100000) / averagePrice > maximumPriceFeedPercentDifferenceTimes1000 )
			return 0;

		return averagePrice;
		}


	function _getPriceBTC(IPriceFeed priceFeed) internal view returns (uint256 price)
		{
 		try priceFeed.getPriceBTC() returns (uint256 _price)
			{
			price = _price;
			}
		catch (bytes memory)
			{
			// price remains 0
			}
		}


	function _getPriceETH(IPriceFeed priceFeed) internal view returns (uint256 price)
		{
 		try priceFeed.getPriceETH() returns (uint256 _price)
			{
			price = _price;
			}
		catch (bytes memory)
			{
			// price remains 0
			}
		}


	// Return the current BTC price (with 18 decimals)
	function getPriceBTC() external view returns (uint256 price)
		{
		uint256 price1 = _getPriceBTC(priceFeed1);
		uint256 price2 = _getPriceBTC(priceFeed2);
		uint256 price3 = _getPriceBTC(priceFeed3);

		price = _aggregatePrices(price1, price2, price3);
		require (price != 0, "Invalid BTC price" );
		}


	// Return the current ETH price (with 18 decimals)
	function getPriceETH() external view returns (uint256 price)
		{
		uint256 price1 = _getPriceETH(priceFeed1);
		uint256 price2 = _getPriceETH(priceFeed2);
		uint256 price3 = _getPriceETH(priceFeed3);

		price = _aggregatePrices(price1, price2, price3);
		require (price != 0, "Invalid ETH price" );
		}
    }