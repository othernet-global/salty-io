// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "forge-std/Test.sol";
import "../../interfaces/IExchangeConfig.sol";
import "../CoreUniswapFeed.sol";


// Prices are returned with 18 decimals.
contract TestUniswapFeed is CoreUniswapFeed
    {
    bool public revertNext = false;

    uint256 public forcedTWAP_WBTC_WETH;
    uint256 public forcedTWAP_WETH_USDC;


	constructor( address _UNISWAP_V3_WBTC_WETH, address _UNISWAP_V3_WETH_USDC, IExchangeConfig _exchangeConfig )
	CoreUniswapFeed( _UNISWAP_V3_WBTC_WETH, _UNISWAP_V3_WETH_USDC, _exchangeConfig )
		{
		}


	function setRevertNext() public
		{
		revertNext = true;
		}


	function setTwapWBTC( uint256 twap ) public
		{
		forcedTWAP_WBTC_WETH = twap;
		}


	function setTwapWETH( uint256 twap ) public
		{
		forcedTWAP_WETH_USDC = twap;
		}


	// Wrap the _getUniswapTwapWei function in a public function that includes a try/catch.
	// Returns zero on any type of failure.
    function getUniswapTwapWei( address pool, uint256 twapInterval ) public override view returns (uint256)
		{
		require( !revertNext, "revertNext is true" );

		if ( pool == UNISWAP_V3_WBTC_WETH )
		if ( forcedTWAP_WBTC_WETH != 0 )
			return forcedTWAP_WBTC_WETH;

		if ( pool == UNISWAP_V3_WETH_USDC )
		if ( forcedTWAP_WETH_USDC != 0 )
			return forcedTWAP_WETH_USDC;

		return super.getUniswapTwapWei( pool, twapInterval );
		}
    }