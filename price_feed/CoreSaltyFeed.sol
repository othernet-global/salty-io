// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../chainlink/AggregatorV3Interface.sol";
import "./interfaces/IPriceFeed.sol";
import "../pools/interfaces/IPools.sol";
import "../interfaces/IExchangeConfig.sol";


// Uses the Salty.IO pools to retrieve prices for BTC and ETH.
// Prices are returned with 18 decimals.
contract CoreSaltyFeed is IPriceFeed
    {
    IPools immutable public pools;

	IERC20 immutable public wbtc;
	IERC20 immutable public weth;
	IERC20 immutable public usds;

	// Token balances less than dust are treated as if they don't exist at all.
	// With the 18 decimals that are used for most tokens, DUST has a value of 0.0000000000000001
	// For tokens with 8 decimal places (like WBTC) DUST has a value of .000001
	uint256 constant public DUST = 100;


	constructor( IPools _pools, IExchangeConfig _exchangeConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		pools = _pools;
		wbtc = _exchangeConfig.wbtc();
		weth = _exchangeConfig.weth();
		usds = _exchangeConfig.usds();
		}


	function getPriceBTC() public view returns (uint256)
		{
        (uint256 reservesWBTC, uint256 reservesUSDS) = pools.getPoolReserves(wbtc, usds);

		if ( ( reservesWBTC < DUST ) || ( reservesUSDS < DUST ) )
			return 0;

		// reservesWBTC has 8 decimals, keep the 18 decimals of reservesUSDS
		return ( reservesUSDS * 10**8 ) / reservesWBTC;
		}


	function getPriceETH() public view returns (uint256)
		{
        (uint256 reservesWETH, uint256 reservesUSDS) = pools.getPoolReserves(weth, usds);

		if ( ( reservesWETH < DUST ) || ( reservesUSDS < DUST ) )
			return 0;

		return ( reservesUSDS * 10**18 ) / reservesWETH;
		}
    }