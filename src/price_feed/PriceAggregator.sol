// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/IPriceAggregator.sol";


// Compares three different price feeds to provide prices for BTC and ETH
// The three price feeds are used so that if one fails to work properly, the other two can still correctly report price (the outlier is discarded).
// setPriceFeed can only be called once every 35 days by default (to allow time to review performance of the most recently upgraded PriceFeed before setting another).
// priceFeed1, priceFeed2, and priceFeed3 are updateable using DAO.proposeSetContractAddress( "priceFeed1" ), etc
contract PriceAggregator is IPriceAggregator, Ownable
    {
    event PriceFeedSet(uint256 indexed priceFeedNum, IPriceFeed indexed newPriceFeed);
    event MaximumPriceFeedPercentDifferenceChanged(uint256 newMaxDifference);
    event SetPriceFeedCooldownChanged(uint256 newCooldown);

	IPriceFeed public priceFeed1; // CoreUniswapFeed by default
	IPriceFeed public priceFeed2; // CoreChainlinkFeed by default
	IPriceFeed public priceFeed3; // CoreSaltyFeed by default

	// The next time at which setPriceFeed can be called
	uint256 public priceFeedModificationCooldownExpiration;

	// The maximum percent difference between two non-zero PriceFeed prices when aggregating price.
	// When the two closest PriceFeeds (out of the three) have prices further apart than this the aggregated price is considered invalid.
	// Range: 1% to 7% with an adjustment of .50%
	uint256 public maximumPriceFeedPercentDifferenceTimes1000 = 3000; // Defaults to 3.0% with a 1000x multiplier

	// The required cooldown between calls to setPriceFeed.
	// Allows time to evaluate the performance of the recently updatef PriceFeed before further updates are made.
	// Range: 30 to 45 days with an adjustment of 5 days
	uint256 public priceFeedModificationCooldown = 35 days;


	function setInitialFeeds( IPriceFeed _priceFeed1, IPriceFeed _priceFeed2, IPriceFeed _priceFeed3 ) public onlyOwner
		{
		require( address(priceFeed1) == address(0), "setInitialFeeds() can only be called once" );

		priceFeed1 = _priceFeed1;
		priceFeed2 = _priceFeed2;
		priceFeed3 = _priceFeed3;
		}


	function setPriceFeed( uint256 priceFeedNum, IPriceFeed newPriceFeed ) public onlyOwner
		{
		// If the required cooldown is not met, simply return without reverting so that the original proposal can be finalized and new setPriceFeed proposals can be made.
		if ( block.timestamp < priceFeedModificationCooldownExpiration )
			return;

		if ( priceFeedNum == 1 )
			priceFeed1 = newPriceFeed;
		else if ( priceFeedNum == 2 )
			priceFeed2 = newPriceFeed;
		else if ( priceFeedNum == 3 )
			priceFeed3 = newPriceFeed;

		priceFeedModificationCooldownExpiration = block.timestamp + priceFeedModificationCooldown;
		emit PriceFeedSet(priceFeedNum, newPriceFeed);
		}


	function changeMaximumPriceFeedPercentDifferenceTimes1000(bool increase) public onlyOwner
		{
        if (increase)
            {
            if (maximumPriceFeedPercentDifferenceTimes1000 < 7000)
                maximumPriceFeedPercentDifferenceTimes1000 += 500;
            }
        else
            {
            if (maximumPriceFeedPercentDifferenceTimes1000 > 1000)
                maximumPriceFeedPercentDifferenceTimes1000 -= 500;
            }

		emit MaximumPriceFeedPercentDifferenceChanged(maximumPriceFeedPercentDifferenceTimes1000);
		}


	function changePriceFeedModificationCooldown(bool increase) public onlyOwner
		{
        if (increase)
            {
            if (priceFeedModificationCooldown < 45 days)
                priceFeedModificationCooldown += 5 days;
            }
        else
            {
            if (priceFeedModificationCooldown > 30 days)
                priceFeedModificationCooldown -= 5 days;
            }

		emit SetPriceFeedCooldownChanged(priceFeedModificationCooldown);
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