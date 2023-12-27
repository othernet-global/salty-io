// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "./UpkeepFlawed.sol";


contract TestUpkeepFlawed is Deployment
	{
    address public constant alice = address(0x1111);


	function _initFlawed( uint256 stepToRevert ) internal
		{
		vm.startPrank(DEPLOYER);
		dai = new TestERC20("DAI", 18);
		weth = new TestERC20("WETH", 18);
		wbtc = new TestERC20("WBTC", 8);
		salt = new Salt();
		vm.stopPrank();

		vm.startPrank(DEPLOYER);

		daoConfig = new DAOConfig();
		poolsConfig = new PoolsConfig();
		usds = new USDS();

		managedTeamWallet = new ManagedWallet(teamWallet, teamConfirmationWallet);
		exchangeConfig = new ExchangeConfig(salt, wbtc, weth, dai, usds, managedTeamWallet );

		priceAggregator = new PriceAggregator();
		priceAggregator.setInitialFeeds( IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)) );

		liquidizer = new Liquidizer(exchangeConfig, poolsConfig);

		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		collateralAndLiquidity = new CollateralAndLiquidity(pools, exchangeConfig, poolsConfig, stakingConfig, stableConfig, priceAggregator, liquidizer);

		stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig, false );
		liquidityRewardsEmitter = new RewardsEmitter( collateralAndLiquidity, exchangeConfig, poolsConfig, rewardsConfig, true );

		saltRewards = new SaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);
		emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

		poolsConfig.whitelistPool( pools,  salt, wbtc);
		poolsConfig.whitelistPool( pools,  salt, weth);
		poolsConfig.whitelistPool( pools,  salt, usds);
		poolsConfig.whitelistPool( pools,  wbtc, usds);
		poolsConfig.whitelistPool( pools,  weth, usds);
		poolsConfig.whitelistPool( pools,  wbtc, dai);
		poolsConfig.whitelistPool( pools,  weth, dai);
		poolsConfig.whitelistPool( pools,  usds, dai);
		poolsConfig.whitelistPool( pools,  wbtc, weth);

		proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

		address oldDAO = address(dao);
		dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig, priceAggregator, liquidityRewardsEmitter, collateralAndLiquidity);

		airdrop = new Airdrop(exchangeConfig, staking);

		accessManager = new AccessManager(dao);

		liquidizer.setContracts(collateralAndLiquidity, pools, dao);

		upkeep = new UpkeepFlawed(pools, exchangeConfig, poolsConfig, daoConfig, stableConfig, priceAggregator, saltRewards, collateralAndLiquidity, emissions, dao, stepToRevert);

		daoVestingWallet = new VestingWallet( address(dao), uint64(block.timestamp), 60 * 60 * 24 * 365 * 10 );
		teamVestingWallet = new VestingWallet( address(upkeep), uint64(block.timestamp), 60 * 60 * 24 * 365 * 10 );

		bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop, 60 * 60 * 24 * 5 );
		initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards, collateralAndLiquidity);

		pools.setContracts(dao, collateralAndLiquidity);
		usds.setCollateralAndLiquidity(collateralAndLiquidity);

		exchangeConfig.setContracts(dao, upkeep, initialDistribution, airdrop, teamVestingWallet, daoVestingWallet );
		exchangeConfig.setAccessManager(accessManager);

		// Transfer ownership of the newly created config files to the DAO
		Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
		Ownable(address(poolsConfig)).transferOwnership( address(dao) );
		Ownable(address(priceAggregator)).transferOwnership(address(dao));
		Ownable(address(daoConfig)).transferOwnership( address(dao) );
		vm.stopPrank();

		vm.startPrank(address(oldDAO));
		Ownable(address(stakingConfig)).transferOwnership( address(dao) );
		Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
		Ownable(address(stableConfig)).transferOwnership( address(dao) );
		vm.stopPrank();

		// Move the SALT to the new initialDistribution contract
		vm.prank(DEPLOYER);
		salt.transfer(address(initialDistribution), 100000000 ether);

		finalizeBootstrap();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();
		}


	function _setupLiquidity() internal
		{
		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 100000 ether );

		vm.prank(address(teamVestingWallet));
		salt.transfer(DEPLOYER, 100000 ether );

		vm.startPrank(DEPLOYER);
		weth.approve( address(collateralAndLiquidity), 300000 ether);
		usds.approve( address(collateralAndLiquidity), 100000 ether);
		dai.approve( address(collateralAndLiquidity), 100000 ether);
		salt.approve( address(collateralAndLiquidity), 100000 ether);

		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, usds, 100000 ether, 100000 ether, 0, block.timestamp, false);
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, dai, 100000 ether, 100000 ether, 0, block.timestamp, false);
		collateralAndLiquidity.depositLiquidityAndIncreaseShare(weth, salt, 100000 ether, 100000 ether, 0, block.timestamp, false);

		vm.stopPrank();
		}


	function _swapToGenerateProfits() internal
		{
		vm.startPrank(DEPLOYER);
		pools.depositSwapWithdraw(salt, weth, 1 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(salt, wbtc, 1 ether, 0, block.timestamp);
		pools.depositSwapWithdraw(weth, wbtc, 1 ether, 0, block.timestamp);
		vm.stopPrank();
		}


	function _generateArbitrageProfits( bool despositSaltUSDS ) internal
		{
		/// Pull some SALT from the daoVestingWallet
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(DEPLOYER, 100000 ether);

		// Mint some USDS
		vm.prank(address(collateralAndLiquidity));
		usds.mintTo(DEPLOYER, 1000 ether);

		vm.startPrank(DEPLOYER);
		salt.approve(address(collateralAndLiquidity), type(uint256).max);
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max);
		weth.approve(address(collateralAndLiquidity), type(uint256).max);
		wbtc.approve(address(collateralAndLiquidity), type(uint256).max);
		weth.approve(address(collateralAndLiquidity), type(uint256).max);

		if ( despositSaltUSDS )
			collateralAndLiquidity.depositLiquidityAndIncreaseShare( salt, weth, 1000 ether, 1000 ether, 0, block.timestamp, false );

		collateralAndLiquidity.depositLiquidityAndIncreaseShare( wbtc, salt, 1000 * 10**8, 1000 ether, 0, block.timestamp, false );
		collateralAndLiquidity.depositCollateralAndIncreaseShare( 1000 * 10**8, 1000 ether, 0, block.timestamp, false );

		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		vm.stopPrank();

		// Place some sample trades to create arbitrage profits
		_swapToGenerateProfits();
		}


	// A unit test to revert step1 and ensure other steps continue functioning
	function testRevertStep1() public
		{
		_initFlawed(1);
		_setupLiquidity();
		_generateArbitrageProfits(false);

    	// Dummy WBTC and WETH to send to Liquidizer
    	vm.prank(DEPLOYER);
    	weth.transfer( address(liquidizer), 50 ether );

    	// Indicate that some USDS should be burned
    	vm.prank( address(collateralAndLiquidity));
    	liquidizer.incrementBurnableUSDS( 40 ether);

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

		uint256 usdsSupply0 = usds.totalSupply();

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// [FAILED] Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
		assertEq( usds.balanceOf( address(liquidizer) ), 0 );

		// [FAILED] 40 ether should have been burnt
		assertEq( usdsSupply0 - usds.totalSupply(), 0 ether );


		// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
		// From the directly added 100 ether + arbitrage profits
    	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


		// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

		// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
		(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
		assertEq( reservesA, 2374966892934008368 ); // Close to 2.375 ether
		assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

		uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
		assertEq( daoLiquidity, 4749933785868016736 ); // Close to 4.75 ether


		// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

		// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
		(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
		assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
		assertEq( reservesB, 9023845464674444490 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

		daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
		assertEq( daoLiquidity, 18048299240633188724 ); // Close to 18.05 ether


		// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
		// Check Step 6. Send SALT Emissions to the SaltRewards contract.
		// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
		// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
		// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
		assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
    	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], expectedStakingRewardsFromBootstrapping + expectedStakingRewardsFromArbitrageProfits + 3836898935172364  );

		bytes32[] memory poolIDs = new bytes32[](5);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usds);
		poolIDs[4] = PoolUtils._poolID(usds,dai);

		// Check if the rewards were transferred to the liquidity contract:
		// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
		// SALT/USDS should received an additional 1% of 10% of 47.185786.
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

		// Expected for all pools
		uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

		// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
       	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;

		// Expected for SALT/USDS
       	uint256 expectedAdditionalForSaltUSDS = ( 185786 ether * 10 ) / 100 / 100;

		assertEq( rewards[0], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
		assertEq( rewards[1], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
		assertEq( rewards[2], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
		assertEq( rewards[3], expectedLiquidityRewardsFromBootstrapping + expectedAdditionalForSaltUSDS + 852644207816081);
		assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


		// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
		// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The DAO currently has all of the SALT/USDS and USDS/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
		uint256 polRewards = rewards[3] + rewards[4];

		// 10% of the POL Rewards for the team wallet
		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
		assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13561675228310502283105 );

		// 50% of the remaining rewards are burned
		uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
		assertEq( salt.totalBurned(), halfOfRemaining + 1 );

		// Other 50% should stay in the DAO
		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
		assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34109667998477929984779 );
		}


	// A unit test to revert step2 and ensure other steps continue functioning
    function testRevertStep2() public
    	{
    	_initFlawed(2);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// [FAILED] Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 0 );


    	// [FAILED] Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 0 ); // Close to 2.375 ether
    	assertEq( reservesB, 0 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 0 ); // Close to 4.75 ether


    	// [FAILED] Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// [FAILED] Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 0 ); // Close to 9.025 ether
    	assertEq( reservesB, 0 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 0 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30835716220238095238095  );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	assertEq( rewards[0], 5834127628968253968253);
    	assertEq( rewards[1], 5834127628968253968253);
    	assertEq( rewards[2], 5834127628968253968253);
    	assertEq( rewards[3], 5741270271164021164021);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), 13561675228310502283105 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 0 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), 34109667998477929984779 );
    	}


	// A unit test to revert step3 and ensure other steps continue functioning
    function testRevertStep3() public
    	{
    	_initFlawed(3);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// [FAILED] Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 0 ); // Close to 2.375 ether
    	assertEq( reservesB, 0 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 0 ); // Close to 4.75 ether


    	// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 9499379908450585589 ); // Close to 9.025 ether
    	assertEq( reservesB, 9489699143208499853 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 18989079051659085442 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30836057905767896890493  );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	assertEq( rewards[0], 5834241524144854519053);
    	assertEq( rewards[1], 5834241524144854519053);
    	assertEq( rewards[2], 5834241524144854519053);
    	assertEq( rewards[3], 5741346201281754864554);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), 14135809848438677769560 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 2583605790576789689049 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), 36693273789054719673829 );
    	}


	// A unit test to revert step4 and ensure other steps continue functioning
    function testRevertStep4() public
    	{
    	_initFlawed(4);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
    	assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


    	// [FAILED] Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 0 ); // Close to 9.025 ether
    	assertEq( reservesB, 0 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 0 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30836121991093864768028  );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	assertEq( rewards[0], 5834262885920177144898);
    	assertEq( rewards[1], 5834262885920177144898);
    	assertEq( rewards[2], 5834262885920177144898);
    	assertEq( rewards[3], 5741360442465303281784);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), 14117230783866057838660 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 2500000000000000000000 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), 36609667998477929984779 );
    	}


	// A unit test to revert step5 and ensure other steps continue functioning
    function testRevertStep5() public
    	{
    	_initFlawed(5);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
    	assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


    	// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
    	assertEq( reservesB, 9014829003115815807 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 18039282779074560041 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30835716220238095238095  );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	assertEq( rewards[0], 5834127628968253968253);
    	assertEq( rewards[1], 5834127628968253968253);
    	assertEq( rewards[2], 5834127628968253968253);
    	assertEq( rewards[3], 5741270271164021164021);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDS and USDS/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3] + rewards[4];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13561675228310502283105 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34109667998477929984779 );
    	}


	// A unit test to revert step6 and ensure other steps continue functioning
    function testRevertStep6() public
    	{
    	_initFlawed(6);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
    	assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


    	// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
    	assertEq( reservesB, 9014829003115815807 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 18039282779074560041 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30000324616660839934269  );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	assertEq( rewards[0], 5555663761109168866978);
    	assertEq( rewards[1], 5555663761109168866978);
    	assertEq( rewards[2], 5555663761109168866978);
    	assertEq( rewards[3], 5555627692591297763171);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDS and USDS/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3] + rewards[4];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13561675228310502283105 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining + 1 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34109667998477929984779 );
    	}


	// A unit test to revert step7 and ensure other steps continue functioning
    function testRevertStep7() public
    	{
    	_initFlawed(7);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
    	assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


    	// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
    	assertEq( reservesB, 9014829003115815807 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 18039282779074560041 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// [FAILED] Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 185786852644207816081089 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 30000000000000000000000 );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	assertEq( rewards[0], expectedLiquidityRewardsFromBootstrapping);
    	assertEq( rewards[1], expectedLiquidityRewardsFromBootstrapping);
    	assertEq( rewards[2], expectedLiquidityRewardsFromBootstrapping);
    	assertEq( rewards[3], expectedLiquidityRewardsFromBootstrapping);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDS and USDS/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3] + rewards[4];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13561675228310502283105 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34109667998477929984779 );
    	}


	// A unit test to revert step8 and ensure other steps continue functioning
    function testRevertStep8() public
    	{
    	_initFlawed(8);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
    	assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


    	// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
    	assertEq( reservesB, 9014829003115815807 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 18039282779074560041 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// [FAILED] Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 0 );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	assertEq( rewards[0], 0);
    	assertEq( rewards[1], 0);
    	assertEq( rewards[2], 0);
    	assertEq( rewards[3], 0);
    	assertEq( rewards[4], 0);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDS and USDS/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3] + rewards[4];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13561675228310502283105 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 0 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), 34109667998477929984779 );
    	}


	// A unit test to revert step9 and ensure other steps continue functioning
    function testRevertStep9() public
    	{
    	_initFlawed(9);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
    	assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


    	// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
    	assertEq( reservesB, 9014829003115815807 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 18039282779074560041 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
       	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], expectedStakingRewardsFromBootstrapping + expectedStakingRewardsFromArbitrageProfits + 3836898935172364  );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
          	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;

    	// Expected for SALT/USDS
          	uint256 expectedAdditionalForSaltUSDS = ( 185786 ether * 10 ) / 100 / 100;

    	assertEq( rewards[0], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[1], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[2], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[3], expectedLiquidityRewardsFromBootstrapping + expectedAdditionalForSaltUSDS + 852644207816081);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// [FAILED] Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), 13561675228310502283105 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 0 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), 34109667998477929984779 );
    	}


	// A unit test to revert step10 and ensure other steps continue functioning
    function testRevertStep10() public
    	{
    	_initFlawed(10);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
    	assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


    	// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
    	assertEq( reservesB, 9014829003115815807 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 18039282779074560041 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
       	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], expectedStakingRewardsFromBootstrapping + expectedStakingRewardsFromArbitrageProfits + 3836898935172364  );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
          	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;

    	// Expected for SALT/USDS
          	uint256 expectedAdditionalForSaltUSDS = ( 185786 ether * 10 ) / 100 / 100;

    	assertEq( rewards[0], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[1], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[2], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[3], expectedLiquidityRewardsFromBootstrapping + expectedAdditionalForSaltUSDS + 852644207816081);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// [FAILED] Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDS and USDS/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3] + rewards[4];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13561675228310502283105 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining + 1 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), 5083604083689893517236 );
    	}


	// A unit test to revert step11 and ensure other steps continue functioning
    function testRevertStep11() public
    	{
    	_initFlawed(11);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Dummy WBTC and WETH to send to Liquidizer
       	vm.prank(DEPLOYER);
       	weth.transfer( address(liquidizer), 50 ether );

       	// Indicate that some USDS should be burned
       	vm.prank( address(collateralAndLiquidity));
       	liquidizer.incrementBurnableUSDS( 40 ether);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049050423279843 );

    	uint256 usdsSupply0 = usds.totalSupply();

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
    	assertEq( usds.balanceOf( address(liquidizer) ), 9975012493753123438 ); // 50 WETH converted to about 50 USDS and then 40 burned

    	// 40 ether should have been burnt
    	assertEq( usdsSupply0 - usds.totalSupply(), 40 ether );


    	// Check Step 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049050423279843 );


    	// Check Step 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.

    	// Check that 5% of the remaining WETH (5% of 95 ether) has been converted to USDS/DAI
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(usds, dai);
    	assertEq( reservesA, 2372593734239580153 ); // Close to 2.375 ether
    	assertEq( reservesB, 2374966892934008368 ); // Close to 2.375 ether

    	uint256 daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai));
    	assertEq( daoLiquidity, 4747560627173588521 ); // Close to 4.75 ether


    	// Check Step 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 90.25 ether) has been converted to SALT/USDS
    	(reservesA, reservesB) = pools.getPoolReserves(salt, usds);
    	assertEq( reservesA, 9024453775958744234 ); // Close to 9.025 ether
    	assertEq( reservesB, 9014829003115815807 ); // Close to 9.025 ether - a little worse because some of the USDS reserve was also used for USDS/DAI POL

    	daoLiquidity = collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds));
    	assertEq( daoLiquidity, 18039282779074560041 ); // Close to 18.05 ether


    	// Check Step 5. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 6. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDS rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
       	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], expectedStakingRewardsFromBootstrapping + expectedStakingRewardsFromArbitrageProfits + 3836898935172364  );

    	bytes32[] memory poolIDs = new bytes32[](5);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usds);
    	poolIDs[4] = PoolUtils._poolID(usds,dai);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / 9 pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDS should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = collateralAndLiquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / 9 / 100;

    	// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
          	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;

    	// Expected for SALT/USDS
          	uint256 expectedAdditionalForSaltUSDS = ( 185786 ether * 10 ) / 100 / 100;

    	assertEq( rewards[0], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[1], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[2], expectedLiquidityRewardsFromBootstrapping + expectedLiquidityRewardsFromArbitrageProfits + 1278966311724122);
    	assertEq( rewards[3], expectedLiquidityRewardsFromBootstrapping + expectedAdditionalForSaltUSDS + 852644207816081);
    	assertEq( rewards[4], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDS and USDS/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3] + rewards[4];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days
    	assertEq( salt.balanceOf(teamWallet), 1129689796375531892719 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining + 1 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days
    	assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34109667998477929984779 );
    	}


	}
