// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IExchangeConfig.sol";
import "../pools/interfaces/IPools.sol";
import "./interfaces/IPriceFeed.sol";
import "../pools/PoolUtils.sol";


// Uses the Salty.IO pools to retrieve prices for BTC and ETH.
// Prices are returned with 18 decimals.
contract CoreSaltyFeed is IPriceFeed
    {
    IPools immutable public pools;

	IERC20 immutable public wbtc;
	IERC20 immutable public weth;
	IERC20 immutable public usdc;


	constructor( IPools _pools, IERC20 _wbtc, IERC20 _weth, IERC20 _usdc )
		{
		pools = _pools;
		wbtc = _wbtc;
		weth = _weth;
		usdc = _usdc;
		}


	// Returns zero for an invalid price
	function getPriceBTC() external view returns (uint256)
		{
        (uint256 reservesWBTC, uint256 reservesUSDC) = pools.getPoolReserves(wbtc, usdc);

		if ( ( reservesWBTC < PoolUtils.DUST ) || ( reservesUSDC < PoolUtils.DUST ) )
			return 0;

		// reservesWBTC has 8 decimals, reservesUSDC has 6 decimals, we want 18 decimals
		return ( reservesUSDC * 10**20 ) / reservesWBTC;
		}


	// Returns zero for an invalid price
	function getPriceETH() external view returns (uint256)
		{
        (uint256 reservesWETH, uint256 reservesUSDC) = pools.getPoolReserves(weth, usdc);

		if ( ( reservesWETH < PoolUtils.DUST ) || ( reservesUSDC < PoolUtils.DUST ) )
			return 0;

		// reservesWETH has 18 decimals, reservesUSDC has 6 decimals, we want 18 decimals
		return ( reservesUSDC * 10**30 ) / reservesWETH;
		}
    }