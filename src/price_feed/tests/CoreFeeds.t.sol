// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../CoreChainlinkFeed.sol";
import "../CoreUniswapFeed.sol";
import "../CoreSaltyFeed.sol";


contract TestCoreFeeds is Deployment
	{
	IPriceFeed public chainlinkFeed;
	IPriceFeed public uniswapFeed;
	IPriceFeed public saltyFeed;

	address public alice = address(0x1111);


	constructor()
		{
		initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);

		if ( keccak256(bytes(vm.envString("NETWORK" ))) == keccak256(bytes("eth" )))
			{
			// Live addresses on Ethereum
			CHAINLINK_BTC_USD = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
			CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
			UNISWAP_V3_BTC_ETH = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
			UNISWAP_V3_USDC_ETH = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

			// Live token addresses
			_testBTC = IERC20(address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599));
			_testETH = IERC20(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
			_testUSDC = IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
			}


		chainlinkFeed = new CoreChainlinkFeed( CHAINLINK_BTC_USD, CHAINLINK_ETH_USD );
		uniswapFeed = new CoreUniswapFeed( IERC20(_testBTC), IERC20(_testETH), IERC20(_testUSDC), UNISWAP_V3_BTC_ETH, UNISWAP_V3_USDC_ETH );
		saltyFeed = new CoreSaltyFeed( pools, exchangeConfig );
		}


	function testSaltyFeed() public
		{
		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 100000000 ether );

		vm.startPrank(DEPLOYER);
		usds.approve( address(collateralAndLiquidity), type(uint256).max );
		weth.approve( address(collateralAndLiquidity), type(uint256).max );
		wbtc.approve( address(collateralAndLiquidity), type(uint256).max );

		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, usds, 1000 ether, 1850000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(wbtc, usds, 100 * 10**8, 2919100 ether, 0, block.timestamp, false );

		vm.stopPrank();

		console.log( "salty btc: ", saltyFeed.getPriceBTC() / 10**18 );
		console.log( "salty eth: ", saltyFeed.getPriceETH() / 10**18 );
		}


	function testChainlink() public view
		{
		console.log( "chainlink btc: ", chainlinkFeed.getPriceBTC() / 10**18 );
		console.log( "chainlink eth: ", chainlinkFeed.getPriceETH() / 10**18 );
		}


	function testUniswap() public view
		{
		console.log( "uniswap btc: ", uniswapFeed.getPriceBTC() / 10**18 );
		console.log( "uniswap eth: ", uniswapFeed.getPriceETH() / 10**18 );
		}
	}