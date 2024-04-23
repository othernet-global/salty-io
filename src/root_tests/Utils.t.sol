// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../dev/Deployment.sol";
import "../dev/Utils.sol";


contract TestUtils is Deployment
	{
	function testUtils() public view
		{
		uint256 usdcPrice;
		uint256 wethPrice;
		uint256 saltPrice;

//		Utils utils = new Utils();

		IPriceFeed priceFeed = IPriceFeed(0x4303c5471A4F68e1DEeAf06cc73e8d190Ed7bcf7);

		usdcPrice = priceFeed.getPriceUSDC();

		IERC20 weth = exchangeConfig.weth();
		IERC20 usdc = exchangeConfig.usdc();
		ISalt salt = exchangeConfig.salt();


		// USDC has 6 decimals, usdcPrice has 8
		// Convert to 18 decimals

		(uint256 reserves1, uint256 reserves2) = pools.getPoolReserves(weth, usdc);
		if ( reserves1 > PoolUtils.DUST )
		if ( reserves2 > PoolUtils.DUST )
			wethPrice = (reserves2 * usdcPrice * 10**12 ) / (reserves1/10**10);

		(reserves1, reserves2) = pools.getPoolReserves(salt, usdc);
		if ( reserves1 > PoolUtils.DUST )
		if ( reserves2 > PoolUtils.DUST )
			{
			uint256 saltPriceUSDC = (reserves2 * usdcPrice * 10**12) / (reserves1/10**10);

			(uint256 reserves1b, uint256 reserves2b) = pools.getPoolReserves(salt, weth);
			if ( reserves1b > PoolUtils.DUST )
			if ( reserves2b > PoolUtils.DUST )
				{
				uint256 saltPriceWETH = (reserves2b * wethPrice) / reserves1b;

				saltPrice = ( saltPriceUSDC * reserves1 + saltPriceWETH * reserves1b ) / ( reserves1 + reserves1b );
				}
			}

		// Convert to 18 decimals
		usdcPrice = usdcPrice * 10**10;



//		utils.corePrices(pools, exchangeConfig, priceFeed);
		}
	}
