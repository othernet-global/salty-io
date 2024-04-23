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
		rewardsConfig = new RewardsConfig();
		stakingConfig = new StakingConfig();
		exchangeConfig = new ExchangeConfig(salt, wbtc, weth, usdc, usdt, teamWallet );

		pools = new Pools(exchangeConfig, poolsConfig);
		staking = new Staking( exchangeConfig, poolsConfig, stakingConfig );
		liquidity = new Liquidity(pools, exchangeConfig, poolsConfig, stakingConfig);

		stakingRewardsEmitter = new RewardsEmitter( staking, exchangeConfig, poolsConfig, rewardsConfig, false );
		liquidityRewardsEmitter = new RewardsEmitter( liquidity, exchangeConfig, poolsConfig, rewardsConfig, true );

		saltRewards = new SaltRewards(stakingRewardsEmitter, liquidityRewardsEmitter, exchangeConfig, rewardsConfig);
		emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );

		// Whitelist the pools
		poolsConfig.whitelistPool(salt, usdc);
		poolsConfig.whitelistPool(salt, weth);
		poolsConfig.whitelistPool(weth, usdc);
		poolsConfig.whitelistPool(weth, usdt);
		poolsConfig.whitelistPool(wbtc, usdc);
		poolsConfig.whitelistPool(wbtc, weth);
		poolsConfig.whitelistPool(usdc, usdt);

		proposals = new Proposals( staking, exchangeConfig, poolsConfig, daoConfig );

		dao = new DAO( pools, proposals, exchangeConfig, poolsConfig, stakingConfig, rewardsConfig, daoConfig, liquidityRewardsEmitter);

		airdrop1 = new Airdrop(exchangeConfig, IAirdrop(address(0x0)));
		airdrop2 = new Airdrop(exchangeConfig, IAirdrop(address(0x0)));

		accessManager = new AccessManager(dao);

		upkeep = new UpkeepFlawed(pools, exchangeConfig, poolsConfig, daoConfig, saltRewards, emissions, dao, stepToRevert);

		daoVestingWallet = new VestingWallet( address(dao), uint64(block.timestamp), 60 * 60 * 24 * 365 * 10 );
		teamVestingWallet = new VestingWallet( address(teamWallet), uint64(block.timestamp), 60 * 60 * 24 * 365 * 10 );

		bootstrapBallot = new BootstrapBallot(exchangeConfig, airdrop1, airdrop2, 60 * 60 * 24 * 3, 60 * 60 * 24 * 45 );
		initialDistribution = new InitialDistribution(salt, poolsConfig, emissions, bootstrapBallot, dao, daoVestingWallet, teamVestingWallet, saltRewards);

		pools.setContracts(dao, liquidity);

		exchangeConfig.setContracts(dao, upkeep, initialDistribution, teamVestingWallet, daoVestingWallet );
		exchangeConfig.setAccessManager(accessManager);

		// Transfer ownership of the newly created config files to the DAO
		Ownable(address(exchangeConfig)).transferOwnership( address(dao) );
		Ownable(address(poolsConfig)).transferOwnership( address(dao) );
		Ownable(address(daoConfig)).transferOwnership( address(dao) );
		Ownable(address(rewardsConfig)).transferOwnership( address(dao) );
		Ownable(address(stakingConfig)).transferOwnership( address(dao) );
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




	function _swapToGenerateProfits() internal
		{
		vm.startPrank(DEPLOYER);
		pools.depositSwapWithdraw(salt, weth, 10 ether, 0, block.timestamp);
		rollToNextBlock();
		pools.depositSwapWithdraw(salt, usdc, 10 ether, 0, block.timestamp);
		rollToNextBlock();
		pools.depositSwapWithdraw(weth, usdc, 10 ether, 0, block.timestamp);
		rollToNextBlock();
		vm.stopPrank();
		}


	function _generateArbitrageProfits() internal
		{
		/// Pull some SALT from the daoVestingWallet
    	vm.prank(address(daoVestingWallet));
    	salt.transfer(DEPLOYER, 100000 ether);

		vm.startPrank(DEPLOYER);
		salt.approve(address(liquidity), type(uint256).max);
		usdc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);

		liquidity.depositLiquidityAndIncreaseShare( salt, weth, 1000 ether, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( usdc, salt, 1000 * 10**6, 1000 ether, 0, 0, 0, block.timestamp, false );
		liquidity.depositLiquidityAndIncreaseShare( usdc, weth, 1000 * 10**6, 1000 ether, 0, 0, 0, block.timestamp, false );

		salt.approve(address(pools), type(uint256).max);
		usdc.approve(address(pools), type(uint256).max);
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
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 0 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 0 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 937737165178571428571  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 223293340773809523809);
		assertEq( rewards[1], 223293340773809523809);
		assertEq( rewards[2], 223293340773809523809);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 8333365043125317097919 );

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 20750078957382039573820 );
    	}



	// A unit test to revert step2 and ensure other steps continue functioning
    function testRevertStep2() public
    	{
    	_initFlawed(2);
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 5003333225751503102 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 0 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 937752018824085378346  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 223298291988980840401);
		assertEq( rewards[1], 223298291988980840401);
		assertEq( rewards[2], 223298291988980840401);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 8333365043125317097919 );

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 20750078957382039573820 );
    	}


	// A unit test to revert step3 and ensure other steps continue functioning
    function testRevertStep3() public
    	{
    	_initFlawed(3);
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 5003333225751503102 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 9506333128927855893 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 937737165178571428571  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 223293340773809523809);
		assertEq( rewards[1], 223293340773809523809);
		assertEq( rewards[2], 223293340773809523809);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 8333365043125317097919 );

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 20759585290510967429713 );
    	}


	// A unit test to revert step4 and ensure other steps continue functioning
    function testRevertStep4() public
    	{
    	_initFlawed(4);
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 5003333225751503102 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 9506333128927855893 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 1 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 937511882916411159819  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 223218246686422767559);
		assertEq( rewards[1], 223218246686422767559);
		assertEq( rewards[2], 223218246686422767559);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 8333365043125317097919 );

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 20759585290510967429713 );
    	}


	// A unit test to revert step5 and ensure other steps continue functioning
    function testRevertStep5() public
    	{
    	_initFlawed(5);
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 5003333225751503102 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 9506333128927855893 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 1593907807888565704294 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 937500000000000000000  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 223214285714285714285);
		assertEq( rewards[1], 223214285714285714285);
		assertEq( rewards[2], 223214285714285714285);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 8333365043125317097919 );

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 20759585290510967429713 );
    	}


	// A unit test to revert step6 and ensure other steps continue functioning
    function testRevertStep6() public
    	{
    	_initFlawed(6);
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 5003333225751503102 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 9506333128927855893 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 0  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 0);
		assertEq( rewards[1], 0);
		assertEq( rewards[2], 0);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 8333365043125317097919 );

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 20759585290510967429713 );
    	}


	// A unit test to revert step7 and ensure other steps continue functioning
    function testRevertStep7() public
    	{
    	_initFlawed(7);
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 5003333225751503102 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 9506333128927855893 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 937749048094982588391  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 223297301745946577082);
		assertEq( rewards[1], 223297301745946577082);
		assertEq( rewards[2], 223297301745946577082);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 9506333128927855893 );

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 8333365043125317097919 );
    	}


	// A unit test to revert step8 and ensure other steps continue functioning
    function testRevertStep8() public
    	{
    	_initFlawed(8);
		_generateArbitrageProfits();

    	// Mimic arbitrage profits deposited as SALT for the DAO
    	vm.prank(DEPLOYER);
    	salt.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	salt.approve(address(pools), 100 ether);
    	pools.deposit(salt, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5003333225751503102 );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		UpkeepFlawed(address(upkeep)).performFlawedUpkeep();
		// ==================


		// Check Step 1. Withdraws deposited SALT arbitrage profits from the Pools contract and rewards the caller of performUpkeep()
		// From the directly added 100 ether + arbitrage profits
    	assertEq( salt.balanceOf(upkeepCaller), 5003333225751503102 );


		// Check Step 2. Burns 10% of the remaining withdrawn salt and sends 10% to the DAO's reserve.

		assertEq( salt.totalBurned(), 9506333128927855893 );

		// Check Step 3. Sends the remaining SALT to SaltRewards.
		// Check Step 4. Send SALT Emissions to the SaltRewards contract.
		// Check Step 5. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
		// Check Step 6. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// Check that 76 ether of SALT had been sent to SaltRewards.
		// Emissions also emit about 1488 SALT to SaltRewards as one hour has gone by since the deployment (delay for the bootstrap ballot to complete).
		// This is due to Emissions holding 50 million SALT and emitting at a default rate of .50% / week.

		// As there were profits, SaltRewards distributed the 1488 ether + 72.2 ether rewards to the rewards emitters.
		// 50% to stakingRewardsEmitter and 50% to liquidityRewardsEmitter, 1% / day for one hour.
		assertEq( salt.balanceOf(address(saltRewards)), 2 ); // should be basically empty now

		// Additionally stakingRewardsEmitter started with 3 million bootstrapping rewards.
		// liquidityRewardsEmitter started with 5 million bootstrapping rewards, divided evenly amongst the initial pools.

		// Determine that rewards were sent correctly by the stakingRewardsEmitter and liquidityRewardsEmitter
		bytes32[] memory poolIDsA = new bytes32[](1);
		poolIDsA[0] = PoolUtils.STAKED_SALT;

		// Check that the staking rewards were transferred to the staking contract:
		// One hour of emitted rewards (1% a day) of (3 million bootstrapping in the stakingRewardsEmitter and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		assertEq( staking.totalRewardsForPools(poolIDsA)[0], 937749048094982588391  );

		bytes32[] memory poolIDs = new bytes32[](3);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,usdc);
		poolIDs[2] = PoolUtils._poolID(usdc,weth);

		// Check if the rewards were transferred to the liquidity contract:
		// One hour of emitted rewards (1% a day)  / numInitialPools of (5 million bootstrapping and 50% of 1560.2 ether)
		// Keep in mind that totalRewards contains rewards that have already been claimed (and become virtual rewards)
		uint256[] memory rewards = liquidity.totalRewardsForPools(poolIDs);

		assertEq( rewards[0], 223297301745946577082);
		assertEq( rewards[1], 223297301745946577082);
		assertEq( rewards[2], 223297301745946577082);


		// Check Step 7. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		// Check Step 8. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

		// The daoVestingWallet contains 25 million SALT and vests over a 10 year period.
		// 100k SALT were removed from it in _generateArbitrageProfits() - so it emits about 34394 in the first 5 days + one hour
		assertEq( salt.balanceOf(address(dao)), 20759585290510967429713 );

		// The teamVestingWallet contains 10 million SALT and vests over a 10 year period.
		// It emits about 13561 in the first 5 days + 1 hour (started at the time of contract deployment)
		assertEq( salt.balanceOf(teamWallet), 0 );
    	}
	}
