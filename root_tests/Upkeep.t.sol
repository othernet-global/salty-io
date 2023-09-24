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

contract TestUpkeep2 is Deployment
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

		accessManager.grantAccess();
		vm.prank(DEPLOYER);
		accessManager.grantAccess();
		vm.prank(alice);
		accessManager.grantAccess();

		// Increase max pools to 100
		for( uint256 i = 0; i < 5; i++ )
			{
			vm.prank(address(dao));
			poolsConfig.changeMaximumWhitelistedPools(true);
			}
		}


    function _createLiquidityAndSwapsInAllPools() internal
    	{
    	vm.prank(address(bootstrapBallot));
    	initialDistribution.distributionApproved();

		uint256 totalPools = 100;

    	// Create additional whitelisted pools
    	for( uint256 i = 0; i < totalPools - 9; i++ )
    		{
    		IERC20 tokenA = new TestERC20( "TEST", 18 );
    		IERC20 tokenB = new TestERC20( "TEST", 18 );

    		vm.prank(address(dao));
    		poolsConfig.whitelistPool(pools, tokenA, tokenB);

    		tokenA.approve(address(pools), type(uint256).max);
			tokenB.approve(address(pools), type(uint256).max);
            pools.addLiquidity(tokenA, tokenB, 1000 ether, 1000 ether, 0, block.timestamp);

	    	// Performs swaps on all of the pools so that arbitrage profits exist everywhere
            pools.depositSwapWithdraw(tokenA, tokenB, 1 ether, 0, block.timestamp);
    		}
    	}


   	// A unit test to check the constructor when supplied parameters contain a zero address. Ensure that the constructor reverts with the correct error message.
	function test_construct_with_zero_addresses_fails() public {

		IPools _pools = IPools(address(0));
		IExchangeConfig _exchangeConfig = IExchangeConfig(address(0));
		IPoolsConfig _poolsConfig = IPoolsConfig(address(0));
		IDAOConfig _daoConfig = IDAOConfig(address(0));
		IPriceAggregator _priceAggregator = IPriceAggregator(address(0));
		ISaltRewards _saltRewards = ISaltRewards(address(0));
		ILiquidity _liquidity = ILiquidity(address(0));
		IEmissions _emissions = IEmissions(address(0));

		vm.expectRevert("_pools cannot be address(0)");
		new Upkeep(_pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_exchangeConfig cannot be address(0)");
		new Upkeep(pools, _exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_poolsConfig cannot be address(0)");
		new Upkeep(pools, exchangeConfig, _poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_daoConfig cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, _daoConfig, priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_priceAggregator cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, _priceAggregator, saltRewards, liquidity, emissions);

		vm.expectRevert("_saltRewards cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, _saltRewards, liquidity, emissions);

		vm.expectRevert("_liquidity cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, _liquidity, emissions);

		vm.expectRevert("_emissions cannot be address(0)");
		new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, _emissions);
	}


    // A unit test to check the performUpkeep function and ensure that lastUpkeepTime state variable is updated.
    function testPerformUpkeep() public
    {
        // Arrange
        vm.prank(DEPLOYER);
        uint256 daoStartingSaltBalance = salt.balanceOf( address(exchangeConfig.dao()) );
        uint256 blockTimeStampBefore = block.timestamp;

        vm.warp( blockTimeStampBefore + 90 ); // Advance the timestamp by 90 seconds

        // Act
        upkeep.performUpkeep();

        // Assert
        uint256 updatedLastUpkeepTime = upkeep.lastUpkeepTime();
        assertEq(updatedLastUpkeepTime, blockTimeStampBefore + 90, "lastUpkeepTime is not updated");

        assertEq(daoStartingSaltBalance, salt.balanceOf( address(exchangeConfig.dao()) ), "Salt balance of dao is not the same");
    }


    // A unit test to verify the onlySameContract modifier. Test by calling a function with the modifier from another contract and ensure it reverts with the correct error message.
	function testUpkeepModifier() public {
        vm.expectRevert("Only callable from within the same contract");
        ITestUpkeep(address(upkeep)).step1();
    }


    // A unit test to verify the performUpkeep function when it is called multiple times in quick succession. Ensure that the lastUpkeepTime is correctly updated on each call.
    function testUpdateLastUpkeepTime() public {

            for (uint i=0; i < 5; i++)
            	{
            	uint256 timeIncrease = i * 1 hours;

                // Increase block time
                vm.warp(block.timestamp + timeIncrease);

                // Execute the performUpkeep function
                upkeep.performUpkeep();

                // Check if lastUpkeepTime has updated correctly
                assertEq(upkeep.lastUpkeepTime(), block.timestamp, "Incorrect lastUpkeepTime");
            	}
        }

    // A unit test to verify that upon deployment, the constructor sets the lastUpkeepTime to the current block's timestamp.
    function test_constructor() public {
			upkeep = new Upkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);

        assertEq(block.timestamp, upkeep.lastUpkeepTime(), "lastUpkeepTime was not set correctly in constructor");
    }


    // A unit test to verify that the performUpkeep function reverts when the block timestamp is less than the last upkeep time.
	function testPerformUpkeepRevertsWhenTimestampLTLastPerformUpkeep() public {
    	upkeep.performUpkeep();

    	vm.warp(block.timestamp - 1 minutes);

    	vm.expectRevert();
    	upkeep.performUpkeep();
    }


    // A unit test to verify that step1() functions correctly
    function testSuccessStep1() public
    	{
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
    	forcedPriceFeed.setBTCPrice( 20000 ether );
    	forcedPriceFeed.setETHPrice( 2000 ether );
    	vm.stopPrank();

		// Step 1. Update the prices of BTC and ETH in the PriceAggregator.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1();

		assertEq( priceAggregator.getPriceBTC(), 20000 ether );
		assertEq( priceAggregator.getPriceETH(), 2000 ether );
    	}


    // A unit test to verify that step2() functions correctly
    function testSuccessStep2() public
    	{
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

		// Step 2. Send WBTC and WETH from the USDS contract to the counterswap addresses (for conversion to USDS) and withdraw USDS from counterswap for burning.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step2();

		// Check that the WBTC and WETH have been sent for counterswap
		assertEq( pools.depositedBalance( Counterswap.WBTC_TO_USDS, wbtc ), 5 ether );
		assertEq( pools.depositedBalance( Counterswap.WETH_TO_USDS, weth ), 50 ether );

		// Check that 20 ether of USDS has been burned
		assertEq( usds.totalSupply(), 10 ether );
    	}


    // A unit test to verify that step3() functions correctly
    function testSuccessStep3() public
    	{
    	// USDS to deposited to counterswap to mimic completed counterswap trades
    	vm.prank( address(collateral));
    	usds.mintTo( address(usds), 30 ether );

    	vm.startPrank(address(usds));
    	usds.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WBTC_TO_USDS, usds, 15 ether);
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_USDS, usds, 15 ether);
		vm.stopPrank();

		// Step 3. Withdraw the remaining USDS already counterswapped from WBTC and WETH (for later formation of SALT/USDS liquidity).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step3();

		// Check that the Upkeep contract withdrew USDS from counterswap
		assertEq( usds.balanceOf(address(upkeep)), 30 ether );
    	}


    // A unit test to verify that step4() functions correctly
    function testSuccessStep4() public
    	{
    	// Arbitrage profits are deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 25 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 25 ether);
    	pools.deposit(weth, 25 ether);
    	vm.stopPrank();

    	assertEq( pools.depositedBalance(address(dao), weth), 25 ether );

		// Step 4. Have the DAO withdraw the WETH arbitrage profits from the Pools contract and send the withdrawn WETH to this contract.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step4();

    	// Confirm the weth has been withdrawn and sent to the upkeep contract
    	assertEq( pools.depositedBalance(address(dao), weth), 0 ether );

    	assertEq( weth.balanceOf(address(upkeep)), 25 ether );
    	}


    // A unit test to verify that step5() functions correctly
    function testSuccessStep5() public
    	{
    	// Mimic withdrawing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(upkeep), 100 ether);

		// Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step5(alice);

    	assertEq( weth.balanceOf(alice), 5 ether );
    	}


    // A unit test to verify that step5() functions correctly
    function testSuccessStep5B() public
    	{
    	// Mimic withdrawing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(upkeep), 100 ether);

		// Step 5. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
    	vm.prank(address(alice));
    	upkeep.performUpkeep();

    	assertEq( weth.balanceOf(alice), 5 ether );
    	}


    // A unit test to verify that step6() functions correctly
    function testSuccessStep6() public
    	{
    	// Mimic withdrawing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(upkeep), 100 ether);

		// Step 6. Send a default 10% (20% / 2 ) of the remaining WETH to counterswap for conversion to USDS (for later formation of SALT/USDS liquidity).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step6();

		// Check that the WETH has been sent to counterswap
		// Only half the specified percent will be used for USDS to form SALT/USDS POL (the other half will be counterswapped into SALT in step7)
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_USDS, weth), 10 ether );
    	}


    // A unit test to verify that step7() functions correctly
    function testSuccessStep7() public
    	{
    	// Mimic withdrawing arbitrage profits
    	vm.prank(DEPLOYER);
    	weth.transfer(address(upkeep), 100 ether);

		// Step 7. Send all remaining WETH to counterswap for conversion to SALT (for later SALT/USDS POL formation and SaltRewards).
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step7();

		// Check that the WETH has been sent to counterswap
    	assertEq( pools.depositedBalance(Counterswap.WETH_TO_SALT, weth), 100 ether );
    	}


    // A unit test to verify that step8() functions correctly
    function testSuccessStep8() public
    	{
    	vm.prank(address(initialDistribution));
    	salt.transfer(address(usds), 15 ether);

    	vm.startPrank(address(usds));
    	salt.approve( address(pools), type(uint256).max );
    	pools.depositTokenForCounterswap(Counterswap.WETH_TO_SALT, salt, 15 ether);
		vm.stopPrank();

		// Step 8. Withdraw SALT from previous counterswaps.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step8();

		// Check that the WETH has been sent to counterswap
    	assertEq( salt.balanceOf(address(upkeep)), 15 ether );
    	}


    // A unit test to verify that step9() functions correctly
    function testSuccessStep9() public
    	{
    	// SALT and USDS to the Upkeep contract
    	vm.prank(address(collateral));
    	usds.mintTo(address(upkeep), 30 ether );

    	vm.prank(address(initialDistribution));
    	salt.transfer(address(upkeep), 15 ether);

		// Check that the initial SALT/USDS reserves are zero
		(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(salt, usds);
		assertEq(reserve0, 0);
		assertEq(reserve1, 0);

		// Step 9. Send SALT and USDS (from steps 8 and 3) to the DAO and have it form SALT/USDS Protocol Owned Liquidity
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step9();

		// Check that SALT/USDS POL has been formed
		(reserve0, reserve1) = pools.getPoolReserves(salt, usds);
		assertEq(reserve0, 15 ether);
		assertEq(reserve1, 30 ether);

		(bytes32 poolID,) = PoolUtils.poolID(salt, usds);

		// liquidity should hold the actually LP in the Pools contract
    	assertEq( pools.getUserLiquidity(address(liquidity), salt, usds), pools.totalLiquidity(poolID) );

		// The DAO should have full share of the liquidity
		assertEq( liquidity.userShareForPool(address(dao), poolID), pools.totalLiquidity(poolID) );
	  	}


    // A unit test to verify that step10() functions correctly
    function testSuccessStep10() public
    	{
    	// Mimics SALT that is already in the DAO
    	uint256 initialSaltInDAO = 1000 ether;

    	// SALT to the DAO (initialSaltInDAO and 15 ether which mimics step9() SALT being transferred from Upkeep to the DAO)
    	vm.startPrank(address(initialDistribution));
    	salt.transfer(address(dao), initialSaltInDAO + 15 ether);
    	vm.stopPrank();

		// Step 10. Send the remaining SALT in the DAO that was withdrawn from counterswap to SaltRewards.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step10(initialSaltInDAO);

		// SaltRewards should now have 15 ether (which doens't include the original amount in the DAO)
		assertEq( salt.balanceOf(address(saltRewards)), 15 ether );
	  	}


    // A unit test to verify that step11() functions correctly
    function testSuccessStep11() public
    	{
		vm.prank(address(bootstrapBallot));
		initialDistribution.distributionApproved();

		assertEq( salt.balanceOf(address(emissions)), 52 * 1000000 ether );

    	uint256 timeElapsed = 1 days;

		// Step 11. Send SALT Emissions to the SaltRewards contract.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step11(timeElapsed);

		// Emissions initial distribution of 52 million tokens stored in the contract is a default .50% per week.
		// Approximately 37142 tokens per day initially.
		assertEq( salt.balanceOf(address(saltRewards)), 37142857142857142857147 );
	  	}


    // A unit test to verify that step12() functions correctly
    function testSuccessStep12() public
    	{
    	vm.startPrank(address(initialDistribution));
    	salt.approve(address(saltRewards), 100 ether);
    	saltRewards.addSALTRewards(100 ether);
    	salt.transfer(DEPLOYER, 1000000 ether);
    	vm.stopPrank();

		bytes32[] memory poolIDs = new bytes32[](3);
		(poolIDs[0],) = PoolUtils.poolID(salt,weth);
		(poolIDs[1],) = PoolUtils.poolID(salt,wbtc);
		(poolIDs[2],) = PoolUtils.poolID(wbtc,weth);

		// Add some dummy initial liquidity
		vm.prank(address(collateral));
		usds.mintTo(DEPLOYER, 1000 ether);

		vm.startPrank(DEPLOYER);
		salt.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);

		liquidity.addLiquidityAndIncreaseShare( salt, weth, 1000 ether, 100 ether, 0, block.timestamp, true );
		liquidity.addLiquidityAndIncreaseShare( wbtc, salt, 10 * 10**8, 1000 ether, 0, block.timestamp, true );
		liquidity.addLiquidityAndIncreaseShare( wbtc, weth, 10 * 10**8, 100 ether, 0, block.timestamp, true );

		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);

		// Place some sample trades to create arbitrage contributions for the pool stats
		console.log( "ARB PROFIT: ", pools.depositedBalance( address(dao), weth ) );
		pools.depositSwapWithdraw(salt, weth, 1 ether, 0, block.timestamp);
		console.log( "ARB PROFIT: ", pools.depositedBalance( address(dao), weth ) );
		pools.depositSwapWithdraw(salt, wbtc, 1 ether, 0, block.timestamp);
		console.log( "ARB PROFIT: ", pools.depositedBalance( address(dao), weth ) );
		pools.depositSwapWithdraw(weth, wbtc, 1 ether, 0, block.timestamp);
		console.log( "ARB PROFIT: ", pools.depositedBalance( address(dao), weth ) );

		uint256[] memory profitsForPools = IPoolStats(address(pools)).profitsForPools(poolIDs);
		for( uint256 i = 0; i < profitsForPools.length; i++ )
			console.log( "PROFIT: ", profitsForPools[i] );

//		// Step 12. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter and call clearProfitsForPools.
//    	vm.prank(address(upkeep));
//    	ITestUpkeep(address(upkeep)).step12(poolIDs);

//		// Emissions initial distribution of 52 million tokens stored in the contract is a default .50% per week.
//		// Approximately 37142 tokens per day initially.
//		assertEq( salt.balanceOf(address(saltRewards)), 37142857142857142857147 );
	  	}



	// A unit test to verify all expected outcomes of a performUpkeep

    // A unit test to verify the step1 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step2 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step3 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step4 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step5 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step6 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step7 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step8 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step9 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step10 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step11 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step12 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step13 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step14 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step15 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step16 function reverts correctly. Ensure that the performUpkeep function continues with the rest of the steps.

    // A unit test to verify the step2 function when the WBTC and WETH balance in the USDS contract are zero. Ensure that the tokens are not transferred.
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
