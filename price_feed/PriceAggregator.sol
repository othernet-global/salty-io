// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "./interfaces/IPriceFeed.sol";


// Aggregates three different prices to provide price for BTC and ETH
// Three price feeds are used so that if one PriceFeed is updated by the DAO and it fails to work properly, the other two can correctly report price.
// A singular PriceFeed can only be upgraded in this contract once every 45 days.
contract PriceAggregator is IPriceFeed
    {
	IPriceFeed public priceFeedA;
	IPriceFeed public priceFeedB;
	IPriceFeed public priceFeedC;

	// Token balances less than dust are treated as if they don't exist at all.
	// With the 18 decimals that are used for most tokens, DUST has a value of 0.0000000000000001
	// For tokens with 8 decimal places (like WBTC) DUST has a value of .000001
	uint256 constant public DUST = 100;


	function getPriceBTC() public view returns (uint256)
		{
		return 0;
		}


	function getPriceETH() public view returns (uint256)
		{
		return 0;
		}
    }