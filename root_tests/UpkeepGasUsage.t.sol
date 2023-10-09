// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "../root_tests/TestERC20.sol";
import "../pools/PoolUtils.sol";
import "../Upkeep.sol";
import "../pools/PoolsConfig.sol";
import "../price_feed/PriceAggregator.sol";
import "../ExchangeConfig.sol";
import "../staking/Liquidity.sol";
import "../stable/Collateral.sol";
import "../pools/Pools.sol";
import "../staking/Staking.sol";
import "../rewards/RewardsEmitter.sol";
import "../dao/Proposals.sol";
import "../dao/DAO.sol";
import "../AccessManager.sol";
import "../launch/InitialDistribution.sol";


contract TestMaxUpkeep is Deployment
	{
    address public constant alice = address(0x1111);


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			// Transfer the salt from the original initialDistribution to the DEPLOYER
			vm.prank(address(initialDistribution));
			salt.transfer(DEPLOYER, 100000000 ether);

			vm.startPrank(DEPLOYER);

			poolsConfig = new PoolsConfig();
			usds = new USDS(wbtc, weth);

			exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, teamWallet );

			priceAggregator = new PriceAggregator();
			priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

			pools = new Pools(exchangeConfig, poolsConfig);
			staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
			liquidity = new Liquidity( pools, exchangeConfig, poolsConfig, stakingConfig );
			collateral = new Collateral(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator);

			stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig );
			liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig );

			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

			poolsConfig.whitelistPool(pools, salt, wbtc);
			poolsConfig.whitelistPool(pools, salt, weth);
			poolsConfig.whitelistPool(pools, salt, usds);
			poolsConfig.whitelistPool(pools, wbtc, usds);
			poolsConfig.whitelistPool(pools, weth, usds);
			poolsConfig.whitelistPool(pools, wbtc, dai);
			poolsConfig.whitelistPool(pools, weth, dai);
			poolsConfig.whitelistPool(pools, usds, dai);
			poolsConfig.whitelistPool(pools, wbtc, weth);

			proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

			address oldDAO = address(dao);
			dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter);

			airdrop = new Airdrop(exchangeConfig, staking);

			accessManager = new AccessManager(dao);

			exchangeConfig.setAccessManager( accessManager );
			exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
			exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
			exchangeConfig.setDAO( dao );
			exchangeConfig.setAirdrop(airdrop);

			saltRewards = new SaltRewards(exchangeConfig, rewardsConfig);

			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);
			exchangeConfig.setUpkeep(upkeep);

			bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop, 60 * 60 * 24 * 3 );
			initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, liquidity);
			exchangeConfig.setInitialDistribution(initialDistribution);

			pools.setDAO(dao);

			usds.setContracts(collateral, pools, exchangeConfig );

			// Transfer ownership of the newly created config files to the DAO
			Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
			Ownable(address(poolsConfig)).transferOwnership( address(dao) );
			Ownable(address(priceAggregator)).transferOwnership(address(dao));
			vm.stopPrank();

			vm.startPrank(address(oldDAO));
			Ownable(address(stakingConfig)).transferOwnership( address(dao) );
			Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
			Ownable(address(stableConfig)).transferOwnership( address(dao) );
			Ownable(address(daoConfig)).transferOwnership( address(dao) );
			vm.stopPrank();

			// Move the SALT to the new initialDistribution contract
			vm.prank(DEPLOYER);
			salt.transfer(address(initialDistribution), 100000000 ether);
			}

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();

		vm.prank(DEPLOYER);
		airdrop.whitelistWallet(alice);

		finalizeBootstrap();

		vm.prank(address(daoVestingWallet));
		salt.transfer(DEPLOYER, 1000000 ether);

		// Increase max pools to 100
		for( uint256 i = 0; i < 5; i++ )
			{
			vm.prank(address(dao));
			poolsConfig.changeMaximumWhitelistedPools(true);
			}
		}


    function setUp() public
    	{
//    	vm.prank(address(bootstrapBallot));
//    	initialDistribution.distributionApproved();

		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		vm.stopPrank();

		uint256 totalPools = 100;

    	// Create additional whitelisted pools
    	while( poolsConfig.numberOfWhitelistedPools() < ( totalPools - 4 ) )
    		{
			vm.startPrank(DEPLOYER);
    		IERC20 tokenA = new TestERC20( "TEST", 18 );
    		IERC20 tokenB = new TestERC20( "TEST", 18 );
    		vm.stopPrank();

    		vm.startPrank(address(dao));
    		poolsConfig.whitelistPool(pools, tokenA, weth);
    		poolsConfig.whitelistPool(pools, tokenA, wbtc);
    		poolsConfig.whitelistPool(pools, tokenB, weth);
    		poolsConfig.whitelistPool(pools, tokenB, wbtc);
			vm.stopPrank();

			vm.startPrank(DEPLOYER);
    		tokenA.approve(address(pools), type(uint256).max);
			tokenB.approve(address(pools), type(uint256).max);
            pools.addLiquidity(tokenA, weth, 1000 ether, 1000 ether, 0, block.timestamp);
            pools.addLiquidity(tokenA, wbtc, 1000 ether, 1000 * 10**8, 0, block.timestamp);
            pools.addLiquidity(tokenB, weth, 1000 ether, 1000 ether, 0, block.timestamp);
            pools.addLiquidity(tokenB, wbtc, 1000 ether, 1000 * 10**8, 0, block.timestamp);

	    	// Performs swaps on all of the pools so that arbitrage profits exist everywhere
            pools.depositSwapWithdraw(tokenA, tokenB, 1 ether, 0, block.timestamp);
            pools.depositSwapWithdraw(tokenA, weth, 1 ether, 0, block.timestamp);
            pools.depositSwapWithdraw(tokenB, weth, 1 ether, 0, block.timestamp);
            pools.depositSwapWithdraw(tokenA, wbtc, 1 ether, 0, block.timestamp);
            pools.depositSwapWithdraw(tokenB, wbtc, 1 ether, 0, block.timestamp);

	    	vm.stopPrank();
    		}


//    	bytes32[] memory poolIDs = poolsConfig.whitelistedPools();
//    	uint256[] memory stats = IPoolStats(address(pools)).profitsForPools(poolIDs);
//    	for( uint256 i = 0; i < poolIDs.length; i++ )
//    		{
//    		console.log( "POOL: ", i, stats[i] );
//    		}
    	}


	// Set the initial storage write baseline for performUpkeep()
    function testGasMaxUpkeepBaseline() public
    	{
    	vm.warp(block.timestamp + 1 hours);
    	upkeep.performUpkeep();

		vm.startPrank(DEPLOYER);
    	forcedPriceFeed.setBTCPrice(28000 ether);
    	forcedPriceFeed.setETHPrice(1800 ether);

		weth.transfer(address(usds), 1000 ether);
		wbtc.transfer(address(usds), 1000 * 10**8);

		weth.transfer(address(upkeep), 10 ether);
		wbtc.transfer(address(upkeep), 10 * 10**8);
    	vm.stopPrank();

		vm.startPrank(address(upkeep));
		weth.approve(address(pools), 10 ether);
		wbtc.approve(address(pools), 10 *10**8);

		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, weth, 5 ether);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, weth, 5 ether);
		pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, wbtc, 1 * 10**8);
		vm.stopPrank();

    	vm.prank(address(collateral));
    	usds.shouldBurnMoreUSDS( 100 ether );
    	}


	// Like the above, but with an extra performUpkeep() so we can see how much gas is involved in just that call
    function testGasMaxUpkeep() public
    	{
    	testGasMaxUpkeepBaseline();

		// Just an extra performUpkeep() call
    	vm.warp(block.timestamp + 1 hours);
    	upkeep.performUpkeep();
    	}
	}
