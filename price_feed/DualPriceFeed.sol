// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/IPriceFeedUniswap.sol";
import "../interfaces/IExchangeConfig.sol";
import "./CoreChainlinkFeed.sol";
import "./CoreUniswapFeed.sol";


// DualPriceFeed.sol retrieves BTC and ETH price data from Chainlink and Uniswap V3.
// If the difference between Chainlink's price and Uniswap's 5-minute TWAP is under 3% then the Uniswap 5-minute TWAP is returned for reasonably fast resolution.
// Otherwise, in the face of price volatility Uniswap's 1-hour TWAP is returned to resist price manipulation.

contract DualPriceFeed is IPriceFeed
    {
	IPriceFeed public chainlinkFeed;
	IPriceFeedUniswap public uniswapFeed;

	// If this restriction needs to be changed then a whole new DualPriceFeed.sol should be used and PriceAggregator.setPriceFeed() called with the updated version.
	uint256 public constant MINIMUM_DEFAULT_PERCENT_DIFF_TIMES_1000 = 3000; // 3% maximum diff


	constructor( address _CHAINLINK_BTC_USD, address _CHAINLINK_ETH_USD, address _UNISWAP_V3_BTC_ETH, address _UNISWAP_V3_USDC_ETH, IExchangeConfig _exchangeConfig )
		{
		require( _CHAINLINK_BTC_USD != address(0), "_CHAINLINK_BTC_USD cannot be address(0)" );
		require( _CHAINLINK_ETH_USD != address(0), "_CHAINLINK_ETH_USD cannot be address(0)" );
		require( _UNISWAP_V3_BTC_ETH != address(0), "_UNISWAP_V3_BTC_ETH cannot be address(0)" );
		require( _UNISWAP_V3_USDC_ETH != address(0), "_UNISWAP_V3_USDC_ETH cannot be address(0)" );

		chainlinkFeed = new CoreChainlinkFeed( _CHAINLINK_BTC_USD, _CHAINLINK_ETH_USD );
		uniswapFeed = new CoreUniswapFeed( _UNISWAP_V3_BTC_ETH, _UNISWAP_V3_USDC_ETH, _exchangeConfig );
		}


	function _absoluteDifference( uint256 x, uint256 y ) internal pure returns (uint256)
		{
		if ( x > y )
			return x - y;

		return y - x;
		}


    function getPriceBTC() public view returns (uint256)
    	{
    	uint256 chainlinkPrice = chainlinkFeed.getPriceBTC();
    	uint256 uniswapPrice5 = uniswapFeed.getTwapWBTC( 5 minutes );

        // Check to see how different the Chainlink and Uniswap prices are
        uint256 diffPercentTimes1000 = ( 100 * 1000 * _absoluteDifference( uniswapPrice5, chainlinkPrice ) ) / chainlinkPrice;

        // Similar prices? Just return the Uniswap 5 minute TWAP
        if ( diffPercentTimes1000 < MINIMUM_DEFAULT_PERCENT_DIFF_TIMES_1000 )
        	return uniswapPrice5;

		// Otherwise return the 1 hour Uniswap TWAP (a longer period to resist price manipulation)
		return uniswapFeed.getTwapWBTC( 60 minutes );
    	}


    function getPriceETH() public view returns (uint256)
    	{
    	uint256 chainlinkPrice = chainlinkFeed.getPriceETH();
    	uint256 uniswapPrice5 = uniswapFeed.getTwapWETH( 5 minutes );

        // Check to see how different the Chainlink and Uniswap prices are
        uint256 diffPercentTimes1000 = ( 100 * 1000 * _absoluteDifference( uniswapPrice5, chainlinkPrice ) ) / chainlinkPrice;

        // Similar prices? Just return Uniswap 5 minute TWAP
        if ( diffPercentTimes1000 < MINIMUM_DEFAULT_PERCENT_DIFF_TIMES_1000 )
        	return uniswapPrice5;

		// Otherwise return the 1 hour Uniswap TWAP (a longer period to resist price manipulation)
		return uniswapFeed.getTwapWETH( 60 minutes );
    	}
    }