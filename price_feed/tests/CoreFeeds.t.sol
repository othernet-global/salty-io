// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../interfaces/IPriceFeedUniswap.sol";
import "../interfaces/IPriceFeed.sol";
import "../CoreChainlinkFeed.sol";
import "../CoreSaltyFeed.sol";
import "../CoreUniswapFeed.sol";


contract TestCoreFeeds is Test, Deployment
	{
	IPriceFeed public chainlinkFeed;
	IPriceFeedUniswap public uniswapFeed;
	IPriceFeed public saltyFeed;

	address public alice = address(0x1111);


	constructor()
		{
		// Test addresses on Sepolia
		address CHAINLINK_BTC_USD = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
		address CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
		address UNISWAP_V3_BTC_ETH = 0xC27D6ACC8560F24681BC475953F27C5F71668448;
		address UNISWAP_V3_USDC_ETH = 0x9014aE623A76499A0f9F326e95f66fc800bF651d;

		chainlinkFeed = new CoreChainlinkFeed( CHAINLINK_BTC_USD, CHAINLINK_ETH_USD );
		uniswapFeed = new CoreUniswapFeed( UNISWAP_V3_BTC_ETH, UNISWAP_V3_USDC_ETH, exchangeConfig );
		saltyFeed = new CoreSaltyFeed( pools, exchangeConfig );
		}


	function testFeeds() public
		{
		console.log( "chainlink btc: ", chainlinkFeed.getPriceBTC() / 10**18 );
		console.log( "chainlink eth: ", chainlinkFeed.getPriceETH() / 10**18 );

		console.log( "uniswap btc: ", uniswapFeed.getTwapWBTC( 5 minutes ) / 10**18 );
		console.log( "uniswap eth: ", uniswapFeed.getTwapWETH( 5 minutes ) / 10**18 );

		vm.prank(address(collateral));
		usds.mintTo(DEPLOYER, 100000000 ether );

		vm.startPrank(DEPLOYER);
		usds.approve( address(pools), type(uint256).max );
		weth.approve( address(pools), type(uint256).max );
		wbtc.approve( address(pools), type(uint256).max );

		pools.addLiquidity(weth, usds, 1000 ether, 1850000 ether, 0, block.timestamp );
		pools.addLiquidity(wbtc, usds, 100 * 10**8, 2919100 ether, 0, block.timestamp );

		vm.stopPrank();

		console.log( "salty btc: ", saltyFeed.getPriceBTC() / 10**18 );
		console.log( "salty eth: ", saltyFeed.getPriceETH() / 10**18 );
		}
	}