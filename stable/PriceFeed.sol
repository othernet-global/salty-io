// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../chainlink/AggregatorV3Interface.sol";
import "../uniswap_v3/IUniswapV3Pool.sol";
import "../uniswap_v3/TickMath.sol";
import "../uniswap_v3/FullMath.sol";
import "../uniswap_v3/FixedPoint96.sol";
import "./interfaces/IPriceFeed.sol";


// PriceFeed retrieves BTC and ETH price data from Chainlink and Uniswap V3.
// It returns the Chainlink price if the difference with Uniswap's 5-minute TWAP is under 3%.
// Otherwise, it uses Uniswap's 1-hour TWAP to resist price manipulation.

contract PriceFeed is IPriceFeed
    {
	uint256 public constant DECIMAL_FACTOR = 10 ** 10;

	// If this restriction needs to be changed then a whole new PriceFeed should be used and StableConfig.setPriceFeed() used
	uint256 public constant MINIMUM_PERCENT_DIFF_FOR_CHAINLINK_ONLY_PRICE_TIMES_1000 = 3000;

	// https://docs.chain.link/data-feeds/price-feeds/addresses
	address immutable public CHAINLINK_BTC_USD;
    address immutable public CHAINLINK_ETH_USD;

    address immutable public UNISWAP_V3_BTC_ETH;
	address immutable public UNISWAP_V3_USDC_ETH;


	constructor( address _CHAINLINK_BTC_USD, address _CHAINLINK_ETH_USD, address _UNISWAP_V3_BTC_ETH, address _UNISWAP_V3_USDC_ETH )
		{
		require( _CHAINLINK_BTC_USD != address(0), "_CHAINLINK_BTC_USD cannot be address(0)" );
		require( _CHAINLINK_ETH_USD != address(0), "_CHAINLINK_ETH_USD cannot be address(0)" );
		require( _UNISWAP_V3_BTC_ETH != address(0), "_UNISWAP_V3_BTC_ETH cannot be address(0)" );
		require( _UNISWAP_V3_USDC_ETH != address(0), "_UNISWAP_V3_USDC_ETH cannot be address(0)" );

		CHAINLINK_BTC_USD = _CHAINLINK_BTC_USD;
		CHAINLINK_ETH_USD = _CHAINLINK_ETH_USD;

		UNISWAP_V3_BTC_ETH = _UNISWAP_V3_BTC_ETH;
		UNISWAP_V3_USDC_ETH = _UNISWAP_V3_USDC_ETH;
		}


	// Chainlink returns prices with 8 decimals
	// Add 10 more decimals so it can be compared with getUniswapTwapWei (which returns 18)
	// Fails if a non-zero price is returned or the _chainlinkFeed address is incorrect
	// virtual - really just needed for the derived unit tests
	function latestChainlinkPrice(address _chainlinkFeed) public virtual view returns (uint256)
		{
		AggregatorV3Interface chainlinkFeed = AggregatorV3Interface(_chainlinkFeed);

		int256 price = 0;

		try chainlinkFeed.latestRoundData()
		returns (
			uint80, // _roundID
			int256 _price,
			uint256, // _startedAt
			uint256, // _timeStamp
			uint80 // _answeredInRound
		)
			{
			price = _price;
			}
		catch (bytes memory) // Catching any failure
			{
			}

		require(price > 0, "PriceFeed: Invalid Chainlink price");

		return uint256(price) * DECIMAL_FACTOR;
		}



	// Returns amount of token0 given token1 * ( 10 ** 18 )
    function _getUniswapTwapWei( address _pool, uint256 twapInterval ) public view returns (uint256)
    	{
		IUniswapV3Pool pool = IUniswapV3Pool( _pool );

		uint32[] memory secondsAgo = new uint32[](2);
		secondsAgo[0] = uint32(twapInterval); // from (before)
		secondsAgo[1] = 0; // to (now)

        // Get the historical tick data using the observe() function
         (int56[] memory tickCumulatives, ) = pool.observe(secondsAgo);

		int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)));
		uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick( tick );
		uint256 p = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96 );

		uint8 decimals0 = ( ERC20( pool.token0() ) ).decimals();
		uint8 decimals1 = ( ERC20( pool.token1() ) ).decimals();

		if ( decimals1 > decimals0 )
			return FullMath.mulDiv( 10 ** ( 18 + decimals1 - decimals0 ), FixedPoint96.Q96, p );

		if ( decimals0 > decimals1 )
			return ( FixedPoint96.Q96 * ( 10 ** 18 ) ) / ( p * ( 10 ** ( decimals0 - decimals1 ) ) );

		return ( FixedPoint96.Q96 * ( 10 ** 18 ) ) / p;
    	}


	// Wrap the _getTwapWei function in a public function that includes a try/catch
	// Fails if a zero TWAP is returned
    function getUniswapTwapWei( address _pool, uint256 twapInterval ) public view returns (uint256)
		{
		// Initialize return value to 0
		uint256 twap = 0;
		try this._getUniswapTwapWei(_pool, twapInterval) returns (uint256 result)
			{
			twap = result;
			}
		catch (bytes memory)
			{
			// In case of failure, twap will remain 0
			}

		require(twap > 0, "PriceFeed: Invalid Uniswap TWAP");

		return twap;
		}


	// Uses BTC/ETH and USDC/ETH pools because they have much higher TVL than just the
	// Uniswap v3 BTC/USD pool on Polygon
	// virtual - really just needed for the derived unit tests
	function getUniswapPriceBTC( uint256 twapInterval ) public virtual view returns (uint256)
		{
    	uint256 uniswapBTC_ETH = getUniswapTwapWei( UNISWAP_V3_BTC_ETH, twapInterval );
        uint256 uniswapUSDC_ETH = getUniswapTwapWei( UNISWAP_V3_USDC_ETH, twapInterval );

        return ( uniswapUSDC_ETH * ( 10 ** 18 ) ) / uniswapBTC_ETH;
		}


	// virtual - really just needed for the derived unit tests
	function getUniswapPriceETH( uint256 twapInterval ) public virtual view returns (uint256)
		{
        return getUniswapTwapWei( UNISWAP_V3_USDC_ETH, twapInterval );
		}


	function _absoluteDifference( uint256 x, uint256 y ) internal pure returns (uint256)
		{
		if ( x > y )
			return x - y;

		return y - x;
		}


    function getPriceBTC() public view returns (uint256)
    	{
    	uint256 chainlinkPrice = latestChainlinkPrice( CHAINLINK_BTC_USD );
    	uint256 uniswapPrice5 = getUniswapPriceBTC( 5 minutes );

        // Check to see how different the Chainlink and Uniswap prices are
        uint256 diffPercentTimes1000 = ( 100 * 1000 * _absoluteDifference( uniswapPrice5, chainlinkPrice ) ) / chainlinkPrice;

        // Less than 3% difference? Just return the Chainlink price
        if ( diffPercentTimes1000 < MINIMUM_PERCENT_DIFF_FOR_CHAINLINK_ONLY_PRICE_TIMES_1000 )
        	return chainlinkPrice;

		// Otherwise return the 1 hour Uniswap TWAP (a longer period to resist price manipulation)
		return getUniswapPriceBTC( 60 minutes );
    	}


    function getPriceETH() public view returns (uint256)
    	{
    	uint256 chainlinkPrice = latestChainlinkPrice( CHAINLINK_ETH_USD );
    	uint256 uniswapPrice5 = getUniswapPriceETH( 5 minutes );

        // Check to see how different the Chainlink and Uniswap prices are
        uint256 diffPercentTimes1000 = ( 100 * 1000 * _absoluteDifference( uniswapPrice5, chainlinkPrice ) ) / chainlinkPrice;

        // Less than default 3% difference? Just return the Chainlink price
        if ( diffPercentTimes1000 < MINIMUM_PERCENT_DIFF_FOR_CHAINLINK_ONLY_PRICE_TIMES_1000 )
        	return chainlinkPrice;

		// Otherwise return the 1 hour Uniswap TWAP (a longer period to resist price manipulation)
		return getUniswapPriceETH( 60 minutes );
    	}
    }