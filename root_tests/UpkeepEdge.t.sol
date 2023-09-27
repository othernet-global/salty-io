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
import "../dao/DAOConfig.sol";
import "./ITestUpkeep.sol";
import "./UpkeepFlawed.sol";
import "./IUpkeepFlawed.sol";

contract TestUpkeepEdge is Deployment
	{
    address public constant alice = address(0x1111);


	function setup() internal
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

		saltRewards = new SaltRewards(exchangeConfig, rewardsConfig);
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

		accessManager = new AccessManager(dao);

		exchangeConfig.setAccessManager( accessManager );
		exchangeConfig.setStakingRewardsEmitter( stakingRewardsEmitter);
		exchangeConfig.setLiquidityRewardsEmitter( liquidityRewardsEmitter);
		exchangeConfig.setDAO( dao );

		upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);
		exchangeConfig.setUpkeep(upkeep);

		daoVestingWallet = new VestingWallet( address(dao), uint64(block.timestamp + 60 * 60 * 24 * 7), 60 * 60 * 24 * 365 * 10 );
		teamVestingWallet = new VestingWallet( address(upkeep), uint64(block.timestamp + 60 * 60 * 24 * 7), 60 * 60 * 24 * 365 * 10 );
		exchangeConfig.setVestingWallets(address(teamVestingWallet), address(daoVestingWallet));

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

		accessManager.grantAccess();
		vm.prank(DEPLOYER);
		accessManager.grantAccess();
		vm.prank(alice);
		accessManager.grantAccess();
		}


	// A unit test to check the behavior of performUpkeep() when the priceAggregator returns zero price
	function testPerformUpkeepZeroPrice() public
		{
		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		// Set an initial price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 10000 ether );
		forcedPriceFeed.setETHPrice( 1000 ether );
		vm.stopPrank();

		priceAggregator.performUpkeep();

		assertEq( priceAggregator.getPriceBTC(), 10000 ether );
		assertEq( priceAggregator.getPriceETH(), 1000 ether );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 0 );
		forcedPriceFeed.setETHPrice( 0 );
		vm.stopPrank();


    	// Dummy WBTC and WETH to send to USDS
    	vm.startPrank(DEPLOYER);
    	wbtc.transfer( address(usds), 5 ether );
    	weth.transfer( address(usds), 50 ether );
    	vm.stopPrank();

    	// USDS to usds contract to mimic withdrawn counterswap trades
    	vm.startPrank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );
    	usds.shouldBurnMoreUSDS( 20 ether );
    	vm.stopPrank();

		assertEq( usds.totalSupply(), 30 ether );


    	// USDS deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();


    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		// Create some initial WBTC/WETH liquidity so that it can receive bootstrapping rewards
		vm.startPrank(DEPLOYER);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		pools.addLiquidity(wbtc, weth, 100 * 10**8, 1000 * 10**8, 0, block.timestamp);
		vm.stopPrank();

		// Need to warp so that there can be some SALT emissions (with there being a week before the rewardsEmitters start emitting)
		vm.warp(upkeep.lastUpkeepTime() + 1 weeks + 1 days);

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000 ether );
		assertEq( salt.balanceOf(address(staking)), 0 );


		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================


		// Check Step 1. Update the prices of BTC and ETH in the PriceAggregator.
		vm.expectRevert( "Invalid WBTC price" );
		priceAggregator.getPriceBTC();

		vm.expectRevert( "Invalid WETH price" );
		priceAggregator.getPriceETH();

		// Check Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether, "step2 A" );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 59500000000000000000, "step2 B" );

		// Check that USDS has been burned
		assertEq( usds.totalSupply(), 40 ether, "step2 C" );

		// Check Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
		assertEq( usds.balanceOf(address(upkeep)), 30 ether, "step3 A" );

		// Check Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether, "step4 A" );

		// Check Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	assertEq( weth.balanceOf(upkeepCaller), 5 ether, "step5 A" );

		// Check Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
		// Includes deposited WETH from step2 as well
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 59500000000000000000, "step6 A" );

		// Check Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 85500000000000000000, "step7 A" );


		// Checking steps 8-9 skipped for now as no one has SALT as it hasn't been distributed yet

		// Check Step 11. Send SALT Emissions to the stakingRewardsEmitter
		// Check Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
		// Check Step 13. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

		// stakingRewardsEmitter starts at 3 million, receives SALT emissions from Step 11 and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3085830000000000000000000, "step11-13 A" );
		assertEq( salt.balanceOf(address(staking)), 31170000000000000000000, "step11-13 B" );

		// liquidityRewardsEmitter starts at 5 million, but doesn't receive SALT emissions yet from Step 11 as there is no arbitrage yet as SALT hasn't been distributed and can't created the needed pools for the arbitrage cycles - and then distributes 1% to the staking contract
		assertEq( salt.balanceOf(address(liquidity)), 49999999999999999999995, "step11-13 C" );

		// Checking step 14 can be ignored for now as the DAO hasn't formed POL yet (as it didn't yet have SALT)

//		// Check Step 15. Send SALT from the DAO vesting wallet to the DAO (linear distribution of 25 million tokens over 10 years).
//    	assertEq( salt.balanceOf(address(dao)), uint256( 25 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 15 A" );
//
//		// Check Step 16. Send SALT from the team vesting wallet to the team (linear distribution over 10 years).
//    	assertEq( salt.balanceOf(address(teamWallet)), uint256( 10 * 1000000 ether ) * 24 hours / (60 * 60 * 24 * 365 * 10), "step 16 A" );


		// Have the team form some initial SALT/USDS liquidity
		vm.prank(address(collateral));
		usds.mintTo(teamWallet, 1 ether);

		vm.startPrank(teamWallet);
		salt.approve(address(pools), 1 ether);
		usds.approve(address(pools), 1 ether);
		pools.addLiquidity(salt, usds, 1 ether, 1 ether, 0, block.timestamp);
		vm.stopPrank();

		// Send some SALT from the teamWallet to mimic WETH to SALT counterswap
		vm.prank(teamWallet);
		salt.transfer(address(upkeep), 1 ether);

		vm.startPrank(address(upkeep));
		salt.approve(address(pools), type(uint256).max);
		pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 1 ether);
		vm.stopPrank();

    	assertEq( salt.balanceOf(address(upkeep)), 0 ether );

		uint256 saltSupply = salt.totalSupply();

		// =====Perform another performUpkeep
		vm.warp(block.timestamp + 1 days);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// =====


		// Check Step 8. Withdraw SALT from previous counterswaps.
		// This is used to form SALT/USDS POL and is sent to the DAO - so the balance here is zero
    	assertEq( salt.balanceOf(address(upkeep)), 0, "step 8 A" );

		// Check Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq( reserve0, 31000000000000000000, "step 9 A" );
		assertEq( reserve1, 31000000000000000000, "step 9 B" );

		// Check Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
		assertEq( salt.balanceOf(address(saltRewards)), 163326428571428571428576, "step 10 A" );

		// Check Step Step 14. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL): send 10% to the team and burn a default 75% of the remaining.
		uint256 saltBurned = saltSupply - salt.totalSupply();

   		assertEq( saltBurned, 7462500000000000000000, "step 14 A" );
		}


    // A unit test to verify the step2 function when the WBTC and WETH balance in the USDS contract are zero. Ensure that the tokens are not transferred.
    function testStep2() public
    	{
		// Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step2();

		// Check that the WBTC and WETH have been sent for counterswap
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 0 );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 0 );
    	}


    // A unit test to verify the step3 function when there is no USDS remaining to withdraw from Counterswap.
    // A unit test to verify the step4 function when the WETH arbitrage profits' withdrawal operation fails. Ensure it reverts with the correct error message.
    // A unit test to verify the step4 function when the DAO's WETH balance is zero.
    // A unit test to verify the step5 function when the arbirtage profits for WETH are zero.
    // A unit test to verify the step5 function when the reward to the caller is zero. Ensure that the function does not perform any transfers.
    // A unit test to verify the step5 function when WETH balance in this contract is zero. Ensure that no reward is transferred to the caller.
    // A unit test to verify the step6 function when the remainder of the WETH balance is zero.
    // A unit test to verify the step6 function when all the WETH balance is used for the reward in step5. Ensure that the function does not perform any deposit actions.
    // A unit test to verify the step6 function when all the WETH balance is not sufficient to form SALT/USDS liquidity. Ensure that it does not perform any deposit actions.
    // A unit test to verify the step7 function when all the WETH balance is used in step6 to form SALT/USDS liquidity. Ensure that it does not perform any deposit actions.
    // A unit test to verify the step7 function when all the WETH balance is not sufficient for conversion to SALT. Ensure that it does not perform any deposit actions.
    // A unit test to verify the step7 function when the remaining WETH balance in the contract is zero. Ensure that the function does not perform any actions.
    // A unit test to verify the step8 function when the deposited SALT in Counterswap is zero.
    // A unit test to verify the step9 function when the formation of SALT/USDS POL fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step9 function when the SALT/USDS balances are not sufficient to form POL. Ensure that it does not perform any formation actions.
    // A unit test to verify the step9 function when the SALT and USDS balance of the contract are zero. Ensure that the function does not perform any actions.
    // A unit test to verify the step9 function. Check if the balance of SALT and USDS in the DAO account has correctly increased.
    // A unit test to verify the step10 function when the dao's current SALT balance is less than the starting SALT balance. Ensure that the function does not send any SALT to saltRewards.
    // A unit test to verify the step10 function when the dao's current SALT balance is more than the starting SALT balance. Ensure that remaining SALT is correctly calculated and sent to saltRewards.
    // A unit test to verify the step10 function when the dao's current SALT balance is equal to the starting SALT balance.
    // A unit test to verify the step10 function when there is no remaining SALT to send to SaltRewards. Ensure that it does not perform any transfer actions.
    // A unit test to verify the step11 function when the Emissions' performUpkeep function does not emit any SALT. Ensure that it does not perform any emission actions.
    // A unit test to verify the step12 function when the profits for pools are zero. Ensure that the function does not perform any actions.
    // A unit test to verify the step12 function when the SaltRewards' performUpkeep function fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step12 function when the clearProfitsForPools function fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step13 function when the distribute SALT rewards function fails in the stakingRewardsEmitter. Ensure that it reverts with the correct error message.
    // A unit test to verify the step13 function when the distribute SALT rewards function fails in the liquidityRewardsEmitter. Ensure that it reverts with the correct error message.
    // A unit test to verify the step14 function when the dao's POL balance is zero. Ensure that the function does not perform any actions.
    // A unit test to verify the step14 function when the DAO's POL balance is not sufficient for distribution. Ensure that it does not perform any distribution actions.
    // A unit test to verify the step15 function when the DAO vesting wallet's release operation fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step15 function when the DAO vesting wallet contains no SALT. Ensure that it does not perform any release actions.
    // A unit test to verify the step15 function when the releasable amount from the DAO vesting wallet is zero. Ensure the function does not perform any actions.
    // A unit test to verify the step15 function when the DAO's vesting wallet does not have any SALT to release. Ensure that the function does not perform any actions.
    // A unit test to verify the step16 function when the releaseable amount from the team vesting wallet is zero. Ensure that the function does not transfer any SALT to the team's wallet.
    // A unit test to verify the step16 function when the team's vesting wallet does not have any SALT to release. Ensure that the function does not perform any actions.
    // A unit test to verify the step16 function when the team vesting wallet's release operation fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step16 function when the team vesting wallet contains no SALT. Ensure that it does not perform any release actions.
	}




