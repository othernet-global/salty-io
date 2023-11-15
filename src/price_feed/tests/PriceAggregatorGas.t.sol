// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../CoreChainlinkFeed.sol";
import "../CoreUniswapFeed.sol";
import "../PriceAggregator.sol";
import "../CoreSaltyFeed.sol";

contract TestPriceAggreagator is PriceAggregator, Deployment
	{
	constructor()
		{
		initializeContracts();

		CoreChainlinkFeed _chainlinkFeed = new CoreChainlinkFeed( CHAINLINK_BTC_USD, CHAINLINK_ETH_USD );
		CoreUniswapFeed _uniswapFeed = new CoreUniswapFeed( IERC20(_testBTC), IERC20(_testETH), IERC20(_testUSDC), UNISWAP_V3_BTC_ETH, UNISWAP_V3_USDC_ETH );
		CoreSaltyFeed _saltyFeed = new CoreSaltyFeed( pools, exchangeConfig );

		setInitialFeeds(_chainlinkFeed, _uniswapFeed, _saltyFeed);
		}


	// Test price feed gas
	function testPriceFeedGas() public view
		{
		uint256 gas0 = gasleft();

		uint256 price1 = _getPriceBTC(priceFeed1);
		uint256 price2 = _getPriceBTC(priceFeed2);
		uint256 price3 = _getPriceBTC(priceFeed3);

		_aggregatePrices(price1, price2, price3);

		console.log( "PRICE FEED GAS: ", gas0 - gasleft() );
		}
	}



