//// SPDX-License-Identifier: BUSL 1.1
//pragma solidity =0.8.21;
//
//import "forge-std/Test.sol";
//import "../../root_tests/TestERC20.sol";
//import "../Pools.sol";
//import "../../dev/Deployment.sol";
//import "../PoolUtils.sol";
//import "../Counterswap.sol";
//import "../../pools/Pools.sol";
//import "../../pools/PoolUtils.sol";
//import "../../arbitrage/ArbitrageSearch.sol";
//import "../../pools/Counterswap.sol";
//import "../../rewards/SaltRewards.sol";
//import "../../stable/Collateral.sol";
//import "../../ExchangeConfig.sol";
//import "../../staking/Staking.sol";
//import "../../rewards/RewardsEmitter.sol";
//import "../../price_feed/tests/IForcedPriceFeed.sol";
//import "../../price_feed/tests/ForcedPriceFeed.sol";
//import "../../pools/PoolsConfig.sol";
//import "../../price_feed/PriceAggregator.sol";
//import "../../dao/Proposals.sol";
//import "../../dao/DAO.sol";
//import "../../AccessManager.sol";
//
//
//contract TestPoolsAndCounterswap is Test, Deployment
//	{
//	TestERC20[] private tokens = new TestERC20[](10);
//
//	address public alice = address(0x1111);
//	address public bob = address(0x2222);
//	address public charlie = address(0x3333);
//
//	ICounterswap public counterswap;
//
//
//	constructor()
//		{
//		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
//		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
//		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
//			{
//			vm.startPrank(DEPLOYER);
//
//			poolsConfig = new PoolsConfig();
//			usds = new USDS(wbtc, weth);
//
//			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, usdc, usds );
//
//			priceAggregator = new PriceAggregator();
//			priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );
//
//			pools = new Pools(exchangeConfig, rewardsConfig, poolsConfig);
//			staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
//			liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
//			collateral = new Collateral(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator);
//
//			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig );
//			liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig );
//
//			emissions = new Emissions( pools, exchangeConfig, rewardsConfig );
//
//			poolsConfig.whitelistPool(pools, salt, wbtc);
//			poolsConfig.whitelistPool(pools, salt, weth);
//			poolsConfig.whitelistPool(pools, salt, usds);
//			poolsConfig.whitelistPool(pools, wbtc, usds);
//			poolsConfig.whitelistPool(pools, weth, usds);
//			poolsConfig.whitelistPool(pools, wbtc, usdc);
//			poolsConfig.whitelistPool(pools, weth, usdc);
//			poolsConfig.whitelistPool(pools, usds, usdc);
//			poolsConfig.whitelistPool(pools, wbtc, weth);
//
//
//			proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );
//
//			address oldDAO = address(dao);
//			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidity, liquidityRewardsEmitter, saltRewards );
//
//			accessManager = new AccessManager(dao);
//
//			exchangeConfig.setAccessManager( accessManager );
//			exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
//			exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
//			exchangeConfig.setDAO( dao );
//
//			IPoolStats(address(pools)).setDAO(dao);
//
//			usds.setCollateral( collateral );
//            usds.setPools( pools );
//			usds.setDAO( dao );
//
//			// Transfer ownership of the newly created config files to the DAO
//			Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
//			Ownable(address(poolsConfig)).transferOwnership( address(dao) );
//			Ownable(address(priceAggregator)).transferOwnership(address(dao));
//			vm.stopPrank();
//
//			vm.startPrank(address(oldDAO));
//			Ownable(address(stakingConfig)).transferOwnership( address(dao) );
//			Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
//			Ownable(address(stableConfig)).transferOwnership( address(dao) );
//			Ownable(address(daoConfig)).transferOwnership( address(dao) );
//			vm.stopPrank();
//			}
//
//		counterswap = ICounterswap(address(pools));
//		}
//
//
//	function setUp() public
//		{
//		vm.startPrank(DEPLOYER);
//		salt.transfer(address(dao), 1000000 ether );
//		weth.transfer(address(dao), 1000000 ether );
//
//		// Create SALT/WETH liquidity
//		vm.startPrank(address(dao));
//		salt.approve( address(pools), type(uint256).max );
//		weth.approve( address(pools), type(uint256).max );
//
//		salt.transfer(alice, 1000 ether);
//		weth.transfer(alice, 1000 ether);
//
//		pools.addLiquidity( salt, weth, 1000 ether, 2000 ether, 0, block.timestamp);
//		vm.stopPrank();
//
//		vm.startPrank(alice);
//		salt.approve( address(pools), type(uint256).max );
//		weth.approve( address(pools), type(uint256).max );
//		vm.stopPrank();
//		}
//
//
//	function _prepareCounterswap() internal
//		{
//		// Establish the average price in PoolStats by placing a normal swap
//		vm.startPrank(alice);
//		pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp );
//		vm.warp( block.timestamp + 5 minutes );
//		vm.stopPrank();
//
//		// Deposit into counterswap indicating the protocol's intention to place a weth->salt trade
//		vm.startPrank(address(dao));
//		weth.approve( address(counterswap), 10000 ether);
//		counterswap.depositTokenForCounterswap(weth, salt, 100 ether);
//		vm.stopPrank();
//		}
//
//
//	// A unit test to check that counterswap behaves as expected with whitelisted pairs.
//	function testSuccessfulCounterswap() public
//		{
//		_prepareCounterswap();
//
//		// Initial stats
//		uint256 startingDeposited = counterswap.tokensDepositedForCounterswap(weth, salt);
//		(uint256 startingReserve0, uint256 startingReserve1) = pools.getPoolReserves( weth, salt );
//
//		// Try a successful counterswap from SALT->WETH (which will happen inside of the depositSwapWithdraw transaction)
//		vm.prank(alice);
//		uint256 wethOut = pools.depositSwapWithdraw( salt, weth, 10 ether, 0, block.timestamp );
//
//		// Determine how much of the WETH deposited into the Counterswap contract was used
//		uint256 usedWETHFromCounterswap = startingDeposited - counterswap.tokensDepositedForCounterswap(weth, salt);
//		uint256 wethThatShouldStillBeDepositedInCounterswap = 100 ether - usedWETHFromCounterswap;
//
//		assertEq( usedWETHFromCounterswap, wethOut, "Incorrect usedWETHFromCounterswap" );
//		assertEq( counterswap.tokensDepositedForCounterswap(weth, salt), wethThatShouldStillBeDepositedInCounterswap );
//
//		// Check the updated token balances deposited into the Pools contract itself are correct
//		assertEq( pools.depositedBalance( address(counterswap), weth), wethThatShouldStillBeDepositedInCounterswap );
//
//		// Counterswap should have acquire the SALT from the user's trade
//		assertEq( pools.depositedBalance( address(counterswap), salt), 10 ether );
//
//		// Reserves should have remained essentially the same (as the counterswap undid the user's swap within the same transaction)
//		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves( weth, salt );
//		assertEq( reserve0, startingReserve0, "Incorrect reserve0" );
//		assertEq( reserve1, startingReserve1 - 1, "Incorrect reserve1" );
//		}
//
//
//	// A unit test to check that counterswap is not executed when the current prices of the tokens are not favorable compared to the recent average ratio fo the two tokens.
//	function testCounterswapWithUnfavorablePrice() public
//		{
//		_prepareCounterswap();
//
//		// Initial stats
//		uint256 startingDeposited = counterswap.tokensDepositedForCounterswap(weth, salt);
//
//		// Try with prices that are not favorable compared to the recent average
//		vm.warp( block.timestamp + 5 minutes );
//
//		vm.prank(alice);
//		// Trading in the same direction as the counterswap we want to perform is not good for the exchange rate for the intended swap
//		pools.depositSwapWithdraw( weth, salt, 100 ether, 0, block.timestamp );
//
//		startingDeposited = counterswap.tokensDepositedForCounterswap(weth, salt);
//		vm.warp( block.timestamp + 5 minutes );
//
//		vm.prank(alice);
//		pools.depositSwapWithdraw( salt, weth, 200 ether, 0, block.timestamp );
//
//		uint256 usedWETHFromCounterswap = startingDeposited - counterswap.tokensDepositedForCounterswap(weth, salt);
//		assertEq( usedWETHFromCounterswap, 0, "Counterswap should not have been used when token prices are not favorable" );
//		assertEq( pools.depositedBalance( address(counterswap), weth), startingDeposited );
//		assertEq( pools.depositedBalance( address(counterswap), salt), 0 );
//		}
//
//
//	// A unit test to check that counterswap is not executed when the user's swapAmountOut is larger than the amount deposited in the Counterswap contract
//	function testCounterswapWithExcessiveSwapAmount() public
//		{
//		_prepareCounterswap();
//
//		// Initial stats
//		uint256 startingDeposited = counterswap.tokensDepositedForCounterswap(weth, salt);
//
//		// Try with excessively large swapOutput which will exceed the deposited amount
//		startingDeposited = counterswap.tokensDepositedForCounterswap(weth, salt);
//		vm.warp( block.timestamp + 5 minutes );
//
//		vm.prank(alice);
//
//		// Trade is in the correct direciton and prices should be good, but the user's amountOut is larger than what we have deposited
//		pools.depositSwapWithdraw( salt, weth, 200 ether, 0, block.timestamp );
//
//		uint256 usedWETHFromCounterswap = startingDeposited - counterswap.tokensDepositedForCounterswap(weth, salt);
//		assertEq( usedWETHFromCounterswap, 0, "Counterswap should not have been used for an excessively large swap" );
//
//		assertEq( pools.depositedBalance( address(counterswap), weth), startingDeposited );
//		assertEq( pools.depositedBalance( address(counterswap), salt), 0 );
//		}
//	}