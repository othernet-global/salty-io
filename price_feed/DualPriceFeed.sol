// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/IPriceFeedUniswap.sol";
import "../interfaces/IExchangeConfig.sol";
import "./CoreChainlinkFeed.sol";
import "./CoreUniswapFeed.sol";


// DualPriceFeed.sol retrieves BTC and ETH price data from Chainlink and Uniswap V3.
// If the difference between Chainlink's price and Uniswap's 5-minute TWAP is under 3% then the Uniswap 5-minute TWAP is returned for reasonably fast price resolution.
// Otherwise, in the face of price volatility Uniswap's 1-hour TWAP is returned to resist price manipulation.

contract DualPriceFeed is IPriceFeed
    {
	IPriceFeed public chainlinkFeed;
	IPriceFeedUniswap public uniswapFeed;

	// If this restriction needs to be changed then a whole new DualPriceFeed.sol should be used and PriceAggregator.setPriceFeed() called with the updated version.
	uint256 public constant MINIMUM_DEFAULT_PERCENT_DIFF_TIMES_1000 = 3000; // 3% maximum diff


	constructor( IPriceFeed _chainlinkFeed, IPriceFeedUniswap _uniswapFeed )
		{
		require( address(_chainlinkFeed) != address(0), "_chainlinkFeed cannot be address(0)" );
		require( address(_uniswapFeed) != address(0), "_uniswapFeed cannot be address(0)" );

		chainlinkFeed = _chainlinkFeed;
		uniswapFeed = _uniswapFeed;
		}


	function _absoluteDifference( uint256 x, uint256 y ) internal pure returns (uint256)
		{
		if ( x > y )
			return x - y;

		return y - x;
		}


    function getPriceBTC() public view returns (uint256)
    	{
    	// Both with 18 decimals
    	uint256 chainlinkPrice = chainlinkFeed.getPriceBTC();
    	uint256 uniswapPrice5 = uniswapFeed.getTwapWBTC( 5 minutes );

    	if ( ( chainlinkPrice == 0 ) || uniswapPrice5 == 0 )
    		return 0;

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
    	// Both with 18 decimals
    	uint256 chainlinkPrice = chainlinkFeed.getPriceETH();
    	uint256 uniswapPrice5 = uniswapFeed.getTwapWETH( 5 minutes );

    	if ( ( chainlinkPrice == 0 ) || uniswapPrice5 == 0 )
    		return 0;

        // Check to see how different the Chainlink and Uniswap prices are
        uint256 diffPercentTimes1000 = ( 100 * 1000 * _absoluteDifference( uniswapPrice5, chainlinkPrice ) ) / chainlinkPrice;

        // Similar prices? Just return Uniswap 5 minute TWAP
        if ( diffPercentTimes1000 < MINIMUM_DEFAULT_PERCENT_DIFF_TIMES_1000 )
        	return uniswapPrice5;

		// Otherwise return the 1 hour Uniswap TWAP (a longer period to resist price manipulation)
		return uniswapFeed.getTwapWETH( 60 minutes );
    	}
    }