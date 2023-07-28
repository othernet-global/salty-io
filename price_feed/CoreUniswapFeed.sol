// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "forge-std/Test.sol";
import "../openzeppelin/token/ERC20/ERC20.sol";
import "../uniswap_v3/IUniswapV3Pool.sol";
import "../uniswap_v3/TickMath.sol";
import "../uniswap_v3/FullMath.sol";
import "../uniswap_v3/FixedPoint96.sol";
import "./interfaces/IPriceFeedUniswap.sol";
import "../interfaces/IExchangeConfig.sol";


// Returns TWAPs for WBTC and WETH for associated Uniswap v3 pools.
// Prices are returned with 18 decimals.
contract CoreUniswapFeed is IPriceFeedUniswap
    {
	// Uniswap v3 pool addresses
    address immutable public UNISWAP_V3_WBTC_WETH;
	address immutable public UNISWAP_V3_WETH_USDC;

	IERC20 immutable public wbtc;
    IERC20 immutable public weth;
    IERC20 immutable public usdc;

    bool immutable public wbtc_wethFlipped;
    bool immutable public weth_usdcFlipped;


	constructor( address _UNISWAP_V3_WBTC_WETH, address _UNISWAP_V3_WETH_USDC, IExchangeConfig _exchangeConfig )
		{
		require( _UNISWAP_V3_WBTC_WETH != address(0), "_UNISWAP_V3_WBTC_WETH cannot be address(0)" );
		require( _UNISWAP_V3_WETH_USDC != address(0), "_UNISWAP_V3_USDC_WETH cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		UNISWAP_V3_WBTC_WETH = _UNISWAP_V3_WBTC_WETH;
		UNISWAP_V3_WETH_USDC = _UNISWAP_V3_WETH_USDC;

		wbtc = _exchangeConfig.wbtc();
		weth = _exchangeConfig.weth();
		usdc = _exchangeConfig.usdc();

		// Assume WBTC/WETH order
		wbtc_wethFlipped = address(weth) < address(wbtc);

		// Assume WETH/USDC order
		weth_usdcFlipped = address(usdc) < address(weth);
		}


	// Returns amount of token0 given token1 * ( 10 ** 18 ) from the given pool
    function _getUniswapTwapWei( address pool, uint256 twapInterval ) public view returns (uint256)
    	{
		IUniswapV3Pool _pool = IUniswapV3Pool( pool );

		uint32[] memory secondsAgo = new uint32[](2);
		secondsAgo[0] = uint32(twapInterval); // from (before)
		secondsAgo[1] = 0; // to (now)

        // Get the historical tick data using the observe() function
         (int56[] memory tickCumulatives, ) = _pool.observe(secondsAgo);

		int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(uint56(twapInterval)));
		uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick( tick );
		uint256 p = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96 );

		uint8 decimals0 = ( ERC20( _pool.token0() ) ).decimals();
		uint8 decimals1 = ( ERC20( _pool.token1() ) ).decimals();

		if ( decimals1 > decimals0 )
			return FullMath.mulDiv( 10 ** ( 18 + decimals1 - decimals0 ), FixedPoint96.Q96, p );

		if ( decimals0 > decimals1 )
			return ( FixedPoint96.Q96 * ( 10 ** 18 ) ) / ( p * ( 10 ** ( decimals0 - decimals1 ) ) );

		return ( FixedPoint96.Q96 * ( 10 ** 18 ) ) / p;
    	}


	// Wrap the _getUniswapTwapWei function in a public function that includes a try/catch.
	// Returns zero on any type of failure.
	// virtual - really just needed for the derived unit tests
    function getUniswapTwapWei( address pool, uint256 twapInterval ) public virtual view returns (uint256)
		{
		// Initialize return value to 0
		uint256 twap = 0;
		try this._getUniswapTwapWei(pool, twapInterval) returns (uint256 result)
			{
			twap = result;
			}
		catch (bytes memory)
			{
			// In case of failure, twap will remain 0
			}

		return twap;
		}


	// Uses WBTC/WETH and WETH/USDC pools because they have much higher TVL than just the Uniswap v3 WBTC/USD pool.
	function getTwapWBTC( uint256 twapInterval ) public virtual view returns (uint256)
		{
    	uint256 uniswapWBTC_WETH = getUniswapTwapWei( UNISWAP_V3_WBTC_WETH, twapInterval );
        uint256 uniswapWETH_USDC = getUniswapTwapWei( UNISWAP_V3_WETH_USDC, twapInterval );

		// Return zero if either is invalid
        if ((uniswapWBTC_WETH == 0) || (uniswapWETH_USDC == 0 ))
	        return 0;

		if ( wbtc_wethFlipped )
			uniswapWBTC_WETH = 10**36 / uniswapWBTC_WETH;

		if ( ! weth_usdcFlipped )
			uniswapWETH_USDC = 10**36 / uniswapWETH_USDC;

		return ( uniswapWETH_USDC * 10**18) / uniswapWBTC_WETH;
		}


	// virtual - really just needed for the derived unit tests
	function getTwapWETH( uint256 twapInterval ) public virtual view returns (uint256)
		{
        uint256 uniswapWETH_USDC = getUniswapTwapWei( UNISWAP_V3_WETH_USDC, twapInterval );

		// Return zero if invalid
        if ( uniswapWETH_USDC == 0 )
	        return 0;

        if ( ! weth_usdcFlipped )
        	return 10**36 / uniswapWETH_USDC;
        else
        	return uniswapWETH_USDC;
		}
    }