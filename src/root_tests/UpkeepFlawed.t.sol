// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "./UpkeepFlawed.sol";


contract TestUpkeepFlawed is Deployment
	{
    address public constant alice = address(0x1111);

	uint256 numInitialPools;


	function _initFlawed( uint256 stepToRevert ) internal
		{
		vm.startPrank(DEPLOYER);
		usdc = new TestERC20("USDC", 6);
		weth = new TestERC20("WETH", 18);
		wbtc = new TestERC20("WBTC", 8);
		salt = new Salt();
		vm.stopPrank();

		vm.startPrank(DEPLOYER);

		daoConfig = new DAOConfig();
		poolsConfig = new PoolsConfig();

		exchangeConfig = new ExchangeConfig(salt, wbtc, weth, usdc, teamWallet );

		priceAggregator = new PriceAggregator(IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)), IPriceFeed(address(forcedPriceFeed)));

		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		liquidity = new Liquidity(pools, exchangeConfig, poolsConfig, stakingConfig);

		stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig, false );
		liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig, true );

		saltRewards = new SaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);
		emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

		poolsConfig.whitelistPool( pools,  salt, wbtc);
		poolsConfig.whitelistPool( pools,  salt, weth);
		poolsConfig.whitelistPool( pools,  salt, usdc);
		poolsConfig.whitelistPool( pools,  wbtc, usdc);
		poolsConfig.whitelistPool( pools,  weth, usdc);
		poolsConfig.whitelistPool( pools,  wbtc, weth);

		proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

		address oldDAO = address(dao);
		dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, daoConfig, liquidityRewardsEmitter, liquidity);

		airdrop = new Airdrop(exchangeConfig, staking);

		accessManager = new AccessManager(dao);

		upkeep = new UpkeepFlawed(pools, exchangeConfig, poolsConfig, daoConfig, saltRewards, emissions, dao, stepToRevert);

		daoVestingWallet = new VestingWallet( address(dao), uint64(block.timestamp), 60 * 60 * 24 * 365 * 10 );
		teamVestingWallet = new VestingWallet( address(teamWallet), uint64(block.timestamp), 60 * 60 * 24 * 365 * 10 );

		bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop, 60 * 60 * 24 * 5 );
		initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, airdrop, saltRewards);

		pools.setContracts(dao, liquidity);

		exchangeConfig.setContracts(dao, upkeep, initialDistribution, airdrop, teamVestingWallet, daoVestingWallet );
		exchangeConfig.setAccessManager(accessManager);

		// Transfer ownership of the newly created config files to the DAO
		Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
		Ownable(address(poolsConfig)).transferOwnership( address(dao) );
		Ownable(address(daoConfig)).transferOwnership( address(dao) );
		vm.stopPrank();

		vm.startPrank(address(oldDAO));
		Ownable(address(stakingConfig)).transferOwnership( address(dao) );
		Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
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

		numInitialPools = poolsConfig.numberOfWhitelistedPools();

    	// Wait an hour to generate some emissions
       	skip( 1 hours );
		}


	function _setupLiquidity() internal
		{
		vm.prank(address(teamVestingWallet));
		salt.transfer(DEPLOYER, 100000 ether );

		vm.startPrank(DEPLOYER);
		weth.approve( address(liquidity), 300000 ether);
		usdc.approve( address(liquidity), 100000 ether);
		salt.approve( address(liquidity), 100000 ether);

		liquidity.depositLiquidityAndIncreaseShare(weth, usdc, 100000 ether, 100000 * 10**6, 0, 0, 0, block.timestamp, false);
		liquidity.depositLiquidityAndIncreaseShare(weth, salt, 100000 ether, 100000 ether, 0, 0, 0, block.timestamp, false);

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



	function _generateArbitrageProfits( bool despositSaltUSDC ) internal
		{
		/// Pull some SALT from the daoVestingWallet
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(DEPLOYER, 100000 ether);

		vm.startPrank(DEPLOYER);
		salt.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);

		if ( despositSaltUSDC )
			liquidity.depositLiquidityAndIncreaseShare( salt, weth, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );

		liquidity.depositLiquidityAndIncreaseShare( wbtc, salt, 1000 * 10**8, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( wbtc, weth, 1000 * 10**8, 1000 ether, 0, 0, 0, block.timestamp, false );

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
    	// Wait an hour to generate some emissions
       	skip( 1 hours );

    	_initFlawed(1);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// [FAILED] Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 0 );


    	// [FAILED] Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// [FAILED] Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 0 ); // Close to 9.5 ether
    	assertEq( reservesB, 0 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 0 ); // Close to 19 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1250290178571428571428  );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	assertEq( rewards[0], 347318948412698412698);
    	assertEq( rewards[1], 347318948412698412698);
    	assertEq( rewards[2], 347318948412698412698);
    	assertEq( rewards[3], 347286706349206349206);


    	// Check Step 7. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), 13674688926940639269406 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 0 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), 34393914573820395738203 );
    	}



	// A unit test to revert step2 and ensure other steps continue functioning
    function testRevertStep2() public
    	{
    	_initFlawed(2);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================

//
    	// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );


    	// [FAILED] Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 0 ); // Close to 9.5 ether
    	assertEq( reservesB, 0 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 0 ); // Close to 18 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 76 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 76 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1250307974696540093726  );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

    	assertEq( rewards[0], 347324880454402253464);
    	assertEq( rewards[1], 347324880454402253464);
    	assertEq( rewards[2], 347324880454402253464);
    	assertEq( rewards[3], 347290661043675576383);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), 13674688926940639269406 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 0 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), 34393914573820395738203 );
    	}


	// A unit test to revert step3 and ensure other steps continue functioning
    function testRevertStep3() public
    	{
    	_initFlawed(3);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================

//
    	// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );


    	// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 9499381149785288726 ); // Close to 9.5 ether
    	assertEq( reservesB, 9499192 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 9499381149794787918 ); // Close to 19 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1250290178571428571428  );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

    	assertEq( rewards[0], 347318948412698412698);
    	assertEq( rewards[1], 347318948412698412698);
    	assertEq( rewards[2], 347318948412698412698);
    	assertEq( rewards[3], 347286706349206349206);


    	// Check Step 7. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDC liquidity - so it will claim all of the above calculated rewards for the pool.
    	uint256 polRewards = rewards[3];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13674688926940639269406 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining + 1 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34393914573820395738203 );
    	}


	// A unit test to revert step4 and ensure other steps continue functioning
    function testRevertStep4() public
    	{
    	_initFlawed(4);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );


    	// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 9499381149785288726 ); // Close to 9.5 ether
    	assertEq( reservesB, 9499192 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 9499381149794787918 ); // Close to 19 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 0 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1250014236912400180234  );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

    	assertEq( rewards[0], 347226967859688948966);
    	assertEq( rewards[1], 347226967859688948966);
    	assertEq( rewards[2], 347226967859688948966);
    	assertEq( rewards[3], 347225385980533373385);


    	// Check Step 7. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDC and USDC/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13674688926940639269406 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34393914573820395738203 );
    	}


	// A unit test to revert step5 and ensure other steps continue functioning
    function testRevertStep5() public
    	{
    	_initFlawed(5);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );


    	// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 9499381149785288726 ); // Close to 9.5 ether
    	assertEq( reservesB, 9499192 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 9499381149794787918 ); // Close to 19 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// [FAILED] Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 5. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 1623549247086675534045 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1250000000000000000000 );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

    	// Expected for all pools
    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / numInitialPools / 100 / 24;

    	assertEq( rewards[0], expectedLiquidityRewardsFromBootstrapping);
    	assertEq( rewards[1], expectedLiquidityRewardsFromBootstrapping);
    	assertEq( rewards[2], expectedLiquidityRewardsFromBootstrapping);
    	assertEq( rewards[3], expectedLiquidityRewardsFromBootstrapping);


    	// Check Step 7. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDC and USDC/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13674688926940639269406 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining + 1 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34393914573820395738203 );
    	}


	// A unit test to revert step6 and ensure other steps continue functioning
    function testRevertStep6() public
    	{
    	_initFlawed(6);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );



    	// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 9499381149785288726 ); // Close to 9.5 ether
    	assertEq( reservesB, 9499192 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 9499381149794787918 ); // Close to 19 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// [FAILED] Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 0 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 0 );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

    	assertEq( rewards[0], 0);
    	assertEq( rewards[1], 0);
    	assertEq( rewards[2], 0);
    	assertEq( rewards[3], 0);


    	// Check Step 7. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDC and USDC/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13674688926940639269406 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 0 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), 34393914573820395738203 );
    	}


	// A unit test to revert step7 and ensure other steps continue functioning
    function testRevertStep7() public
    	{
    	_initFlawed(7);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );


    	// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 9499381149785288726 ); // Close to 9.5 ether
    	assertEq( reservesB, 9499192 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 9499381149794787918 ); // Close to 19 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 0 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
//    	uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
//       	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1250304415483828751662  );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

//    	// Expected for all pools
//    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / numInitialPools / 100 / 24;
//
//    	// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
//          	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;
//
//    	// Expected for SALT/USDC
//          	uint256 expectedAdditionalForSaltUSDC = ( 185786 ether * 10 ) / 100 / 100;

    	assertEq( rewards[0], 347323694050165139443);
    	assertEq( rewards[1], 347323694050165139443);
    	assertEq( rewards[2], 347323694050165139443);
    	assertEq( rewards[3], 347289870107517500369);


    	// [FAILED] Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), 13674688926940639269406 );

    	// 50% of the remaining rewards are burned
    	assertEq( salt.totalBurned(), 0 );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), 34393914573820395738203 );
    	}


	// A unit test to revert step8 and ensure other steps continue functioning
    function testRevertStep8() public
    	{
    	_initFlawed(8);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );


    	// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 9499381149785288726 ); // Close to 9.5 ether
    	assertEq( reservesB, 9499192 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 9499381149794787918 ); // Close to 19 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 0 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
//    	uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
//       	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1250304415483828751662  );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

//    	// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
//          	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;
//
//    	// Expected for SALT/USDC
//          	uint256 expectedAdditionalForSaltUSDC = ( 185786 ether * 10 ) / 100 / 100;
//
//    	// Expected for all pools
//    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / numInitialPools / 100 / 24;

    	assertEq( rewards[0], 347323694050165139443);
    	assertEq( rewards[1], 347323694050165139443);
    	assertEq( rewards[2], 347323694050165139443);
    	assertEq( rewards[3], 347289870107517500369);


    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// [FAILED] Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDC and USDC/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), polRewards / 10 + 13674688926940639269406 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), 156280441548382875167 );
    	}


	// A unit test to revert step9 and ensure other steps continue functioning
    function testRevertStep9() public
    	{
    	_initFlawed(9);
    	_setupLiquidity();
    	_generateArbitrageProfits(false);

       	// Mimic arbitrage profits deposited as WETH for the DAO
       	vm.prank(DEPLOYER);
       	weth.transfer(address(dao), 100 ether);

       	vm.startPrank(address(dao));
       	weth.approve(address(pools), 100 ether);
       	pools.deposit(weth, 100 ether);
       	vm.stopPrank();

    	assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000002 );
    	assertEq( salt.balanceOf(address(staking)), 0 );

    	assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

    	// === Perform upkeep ===
    	address upkeepCaller = address(0x9999);

    	vm.prank(upkeepCaller);
    	UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
    	// ==================


    	// Check Step 1. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
    	// From the directly added 100 ether + arbitrage profits
       	assertEq( weth.balanceOf(upkeepCaller), 5000049714925620913 );


    	// Check Step 2. Convert a default 20% of the remaining WETH to SALT/USDC Protocol Owned Liquidity.

    	// Check that 20% of the remaining WETH (20% of 95 ether) has been converted to SALT/USDC
    	(uint256 reservesA, uint256 reservesB) = pools.getPoolReserves(salt, usdc);
    	assertEq( reservesA, 9499381149785288726 ); // Close to 9.5 ether
    	assertEq( reservesB, 9499192 ); // Close to 9.5 ether - a little worse because some of the USDC reserve was also used for USDC/DAI POL

    	uint256 daoLiquidity = liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc));
    	assertEq( daoLiquidity, 9499381149794787918 ); // Close to 19 ether


    	// Check Step 3. Convert remaining WETH to SALT and sends it to SaltRewards.
    	// Check Step 4. Send SALT Emissions to the SaltRewards contract.
    	// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
    	// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

    	// Check that about 72.2 ether of WETH has been converted to SALT and sent to SaltRewards.
    	// Emissions also emit about 185715 SALT as 5 days (changed to one hour) have gone by since the deployment (delay for the bootstrap ballot to complete).
    	// This is due to Emissions holding 52 million SALT and emitting at a default rate of .50% / week.

    	// As there were profits, SaltRewards distributed the 185715 ether + 72.2 ether rewards
    	// 10% to SALT/USDC rewards, 45% to stakingRewardsEmitter and 45% to liquidityRewardsEmitter,
    	assertEq( salt.balanceOf(address(saltRewards)), 0 ); // should be basically empty now

    	// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
    	// liquidityRewardsEmitter started with 5 millions bootstrapping rewards, divided evenly amongst the 9 initial pools.

    	// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
    	bytes32[] memory poolIDsA = new bytes32[](1);
    	poolIDsA[0] = PoolUtils.STAKED_SALT;

    	// Check that the staking rewards were transferred to the staking contract:
    	// 1% max of (3 million bootstrapping in the stakingRewardsEmitter + 45% of 185786 ether sent from saltRewards)
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
//    	uint256 expectedStakingRewardsFromBootstrapping = uint256(3000000 ether) / 100;
//       	uint256 expectedStakingRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100;
    	assertEq( staking.totalRewardsForPools(poolIDsA)[0], 1250304415483828751662  );

    	bytes32[] memory poolIDs = new bytes32[](4);
    	poolIDs[0] = PoolUtils._poolID(salt,weth);
    	poolIDs[1] = PoolUtils._poolID(salt,wbtc);
    	poolIDs[2] = PoolUtils._poolID(wbtc,weth);
    	poolIDs[3] = PoolUtils._poolID(salt,usdc);

    	// Check if the rewards were transferred to the liquidity contract:
    	// 1% max of ( 5 million / num initial pools + 45% of 185786 ether sent from saltRewards).
    	// SALT/USDC should received an additional 1% of 10% of 47.185786.
    	// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
    	uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

//    	// Expected for WBTC/WETH, SALT/WETH and SALT/WTBC
//          	uint256 expectedLiquidityRewardsFromArbitrageProfits = uint( 185786 ether * 45 ) / 100 / 100 / 3;
//
//    	// Expected for SALT/USDC
//          	uint256 expectedAdditionalForSaltUSDC = ( 185786 ether * 10 ) / 100 / 100;
//
//    	// Expected for all pools
//    	uint256 expectedLiquidityRewardsFromBootstrapping = uint256(5000000 ether) / numInitialPools / 100 / 24;

    	assertEq( rewards[0], 347323694050165139443);
    	assertEq( rewards[1], 347323694050165139443);
    	assertEq( rewards[2], 347323694050165139443);
    	assertEq( rewards[3], 347289870107517500369);

    	// Check Step 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity: send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
    	// Check Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
    	// Check Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

    	// The DAO currently has all of the SALT/USDC and USDC/DAI liquidity - so it will claim all of the above calculated rewards for those two pools.
    	uint256 polRewards = rewards[3];

    	// 10% of the POL Rewards for the team wallet
    	// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _setupLiquidity() - so it emits about 13561 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(teamWallet), 34728987010751750036 );

    	// 50% of the remaining rewards are burned
    	uint256 halfOfRemaining = ( polRewards * 45 ) / 100;
    	assertEq( salt.totalBurned(), halfOfRemaining );

    	// Other 50% should stay in the DAO
    	// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
    	// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34110 in the first 5 days (changed to one hour)
    	assertEq( salt.balanceOf(address(dao)), halfOfRemaining + 1 + 34393914573820395738203 );
    	}


	}
