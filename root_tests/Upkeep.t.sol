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
import "./TestUpkeep.sol";


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

			saltRewards = new SaltRewards(exchangeConfig, rewardsConfig);

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


//   // A unit test to verify the _withdrawTokenFromCounterswap function when the token deposited in Counterswap is non-zero. Ensure that it correctly executes and updates the balance.
//function testWithdrawTokenFromCounterswap() public
//    {
//        // Mock setup
//        TestERC20 token = new TestERC20('Test Token', 18);
//        address counterswapAddress = address(0x123);
//
//        // Mint some tokens to the counterswap address
//        token.transfer(counterswapAddress, 50 ether);
//
//        vm.startPrank(counterswapAddress);
//        token.approve(address(pools), 50 ether);
//        pools.deposit(token, 50 ether);
//        vm.stopPrank();
//
//        // Instantiate TestUpkeep contract
//	    TestUpkeep upkeep = new TestUpkeep(pools, exchangeConfig, poolsConfig, daoConfig, priceAggregator, saltRewards, liquidity, emissions);
//
//        // Act
//        vm.prank(address(usds));
//        upkeep.withdrawTokenFromCounterswap(token, counterswapAddress);
//
//        // Assert
//        uint256 tokenDepositedInCounterswap = pools.depositedBalance( counterswapAddress, token );
//        assertEq(token.balanceOf(counterswapAddress), 0);
//        assertEq(tokenDepositedInCounterswap, 0);
//    }


    // A unit test to verify the _withdrawTokenFromCounterswap function when the token deposited in Counterswap is zero. Ensure that the function does not perform any actions.
    // A unit test to verify the onlySameContract modifier. Test by calling a function with the modifier from another contract and ensure it reverts with the correct error message.
    // A unit test to verify the step1 function. Ensure that the priceAggregator contract's performUpkeep function is called.
    // A unit test to verify the step2 function. Ensure that the usds contract's performUpkeep function is called.
    // A unit test to verify the step3 function. Ensure that the _withdrawTokenFromCounterswap function is called with correct arguments.
    // A unit test to verify the step4 function. Ensure that the dao's withdrawArbitrageProfits function is called with correct argument.
    // A unit test to verify the step5 function. Ensure that the expected WETH reward is transferred to the caller.
    // A unit test to verify the step6 function. Ensure that the pools' depositTokenForCounterswap function is called with correct arguments.
    // A unit test to verify the step7 function. Ensure that the pools' depositTokenForCounterswap function is called with correct arguments.
    // A unit test to verify the step8 function. Ensure that the _withdrawTokenFromCounterswap function is called with correct arguments.
    // A unit test to verify the step9 function. Ensure that the dao's formPOL function is called with correct arguments.
    // A unit test to verify the step10 function. Ensure that the dao's sendSaltToSaltRewards function is called with correct arguments.
    // A unit test to verify the step11 function. Ensure that the emissions' performUpkeep function is called with correct argument.
    // A unit test to verify the step12 function. Check if the expected SALT rewards are distributed and profits were correctly cleared.
    // A unit test to verify the step13 function. Ensure that the stakingRewardsEmitter and liquidityRewardsEmitter's performUpkeep functions are called with correct arguments.
    // A unit test to verify the step14 function. Ensure that the dao's processRewardsFromPOL function is called with correct arguments.
    // A unit test to verify the step15 function. Ensure that the dao's vesting wallet correctly releases SALT.
    // A unit test to verify the step16 function. Ensure that the team's vesting wallet correctly releases SALT and is transferred to team's wallet.
    // A unit test to verify the performUpkeep function when called after a period of time. Ensure that the timeSinceLastUpkeep is correctly calculated and used in step11 and step13.
    // A unit test to verify the step10 function when the dao's current SALT balance is less than the starting SALT balance. Ensure that the function does not send any SALT to saltRewards.
    // A unit test to verify the step10 function when the dao's current SALT balance is more than the starting SALT balance. Ensure that remaining SALT is correctly calculated and sent to saltRewards.
    // A unit test to verify that the performUpkeep function correctly catches and logs errors from any step function.
    // A unit test to verify the step16 function when the releaseable amount from the team vesting wallet is zero. Ensure that the function does not transfer any SALT to the team's wallet.
    // A unit test to verify the step16 function when the releaseable amount from the team vesting wallet is non-zero. Ensure that the function correctly transfers the releaseable amount of SALT to the team's wallet.
    // A unit test to verify the step15 function when the releaseable amount from the DAO vesting wallet is non-zero. Ensure the vesting wallet correctly releases the releasable SALT to DAO.
    // A unit test to verify the performUpkeep function with a non-zero address set as the caller of the function in step5. Ensure that the expected reward is transferred to the caller.
    // A unit test to verify the step7 function when the remaining WETH balance in the contract is zero. Ensure that the function does not perform any actions.
    // A unit test to verify the step7 function when the remaining WETH balance in the contract is non-zero. Ensure that the function correctly executes and updates the balance.
    // A unit test to verify the step9 function when the SALT and USDS balance of the contract are zero. Ensure that the function does not perform any actions.
    // A unit test to verify the step9 function when the SALT and USDS balance in the contract are non-zero. Ensure that the function correctly forms SALT/USDS Protocol Owned Liquidity.
    // A unit test to verify the step2 function when the WBTC and WETH balance in the USDS contract are non-zero. Ensure that the tokens are correctly transferred to the counterswap addresses and USDS is withdrawn for burning.
    // A unit test to verify the step12 function when the profits for pools are zero. Ensure that the function does not perform any actions.
    // A unit test to verify the step12 function when the profits for pools are non-zero. Ensure that the SALT is correctly distributed and profits were correctly cleared.
    // A unit test to verify the constructor when all addresses are the same. Ensure that the constructor reverts with the correct error message.
    // A unit test to verify the step15 function when the releasable amount from the DAO vesting wallet is zero. Ensure the function does not perform any actions.
    // A unit test to verify the performUpkeep function when the block timestamp is the same as the last upkeep time. Ensure that the timeSinceLastUpkeep is correctly calculated as zero and used in step11 and step13.
    // A unit test to verify the performUpkeep function when it is called multiple times in quick succession. Ensure that the lastUpkeepTime is correctly updated each time and the second call does not revert due to the previous state.
    // A unit test to verify the step1 function when the priceAggregator contract's performUpkeep function reverts. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step2 function when the usds contract's performUpkeep function reverts. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify the step5 function when the reward to the caller is zero. Ensure that the function does not perform any transfers.
    // A unit test to verify the step6 function when the depositTokenForCounterswap function reverts. Ensure that the function does not prevent the performUpkeep function from continuing.
    // A unit test to verify the step9 function. Check if the balance of SALT and USDS in the DAO account has correctly increased.
    // A unit test to verify the step14 function when the processRewardsFromPOL function reverts. Check if the performUpkeep function continues with the rest of the steps.
    // A unit test to verify lastUpkeepTime state variable. Ensure that it is correctly set and updated on each call to performUpkeep.
    // A unit test to verify the step15 function when the DAO's vesting wallet does not have any SALT to release. Ensure that the function does not perform any actions.
    // A unit test to verify that upon deployment, the constructor sets the lastUpkeepTime to the current block's timestamp.
    // A unit test to verify the step16 function when the team's vesting wallet does not have any SALT to release. Ensure that the function does not perform any actions.
    // A unit test to verify the performUpkeep function when called from an account that is not the contract itself. Ensure the function reverts with the correct error message.
    // A unit test to verify the _withdrawTokenFromCounterswap function when the deposited token balance in the counterswap address is zero. Ensure that the function does not perform any withdraw operation.
    // A unit test to verify the _withdrawTokenFromCounterswap function when the withdraw operation reverts. Ensure that the function catches and handles the error correctly.
    // A unit test to verify the performUpkeep function when all the steps succeed. Ensure that the function completes without any errors and updates the state variables correctly.
    // A unit test to verify the step3 function when the deposited USDS in Counterswap is some arbitrary non-zero number.
    // A unit test to verify the step4 function when the DAO's WETH balance is zero.
    // A unit test to verify the step4 function when the DAO's WETH balance is non-zero.
    // A unit test to verify the step5 function when the arbirtage profits for WETH are zero.
    // A unit test to verify the step5 function when the arbirtage profits for WETH are non-zero.
    // A unit test to verify the step6 function when the remainder of the WETH balance is zero.
    // A unit test to verify the step6 function when the remainder of the WETH balance is non-zero.
    // A unit test to verify the step8 function when the deposited SALT in Counterswap is zero.
    // A unit test to verify the step8 function when the deposited SALT in Counterswap is non-zero.
    // A unit test to verify the step10 function when the dao's current SALT balance is equal to the starting SALT balance.
    // A unit test to verify the step11 function when the Emissions' performUpkeep function reverts. Ensure that the performUpkeep function continues with the rest of the steps.
    // A unit test to verify that the performUpkeep function correctly calculates the timeSinceLastUpkeep when the block timestamp is greater than the last upkeep time.
    // A unit test to verify that the performUpkeep function correctly calculates the timeSinceLastUpkeep when the block timestamp is less than the last upkeep time.
    // A unit test to verify that the performUpkeep function reverts when it is called before the minimum upkeep interval has passed.
    // A unit test to verify the step14 function when the dao's POL balance is zero. Ensure that the function does not perform any actions.
    // A unit test to verify the step1 function when the priceAggregator contract's performUpkeep function does not cause an update in the prices.
    // A unit test to verify the step2 function when the WBTC and WETH balance in the USDS contract are zero. Ensure that the tokens are not transferred.
    // A unit test to verify the constructor when supplied parameters are empty arrays. Ensure that the constructor reverts with the correct error message.
    // A unit test to verify the step3 function when there is no USDS remaining to withdraw from Counterswap.
    // A unit test to verify the step3 function when the USDS balance in Counterswap exceeds the float ranges. Ensure that it reverts with the correct error message.
    // A unit test to verify the step4 function when the WETH arbitrage profits' withdrawal operation fails. Ensure it reverts with the correct error message.
    // A unit test to verify the step5 function when WETH balance in this contract is zero. Ensure that no reward is transferred to the caller.
    // A unit test to verify the step6 function when all the WETH balance is used for the reward in step5. Ensure that the function does not perform any deposit actions.
    // A unit test to verify the step6 function when all the WETH balance is not sufficient to form SALT/USDS liquidity. Ensure that it does not perform any deposit actions.
    // A unit test to verify the step7 function when all the WETH balance is used in step6 to form SALT/USDS liquidity. Ensure that it does not perform any deposit actions.
    // A unit test to verify the step7 function when all the WETH balance is not sufficient for conversion to SALT. Ensure that it does not perform any deposit actions.
    // A unit test to verify the step8 function when the deposited SALT in Counterswap exceeds the float ranges. Ensure that it reverts with the correct error message.
    // A unit test to verify the step9 function when the formation of SALT/USDS POL fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step9 function when the SALT/USDS balances are not sufficient to form POL. Ensure that it does not perform any formation actions.
    // A unit test to verify the step10 function when there is no remaining SALT to send to SaltRewards. Ensure that it does not perform any transfer actions.
    // A unit test to verify the step11 function when the Emissions' performUpkeep function does not emit any SALT. Ensure that it does not perform any emission actions.
    // A unit test to verify the step12 function when the SaltRewards' performUpkeep function fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step12 function when the clearProfitsForPools function fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step13 function when the distribute SALT rewards function fails in the stakingRewardsEmitter. Ensure that it reverts with the correct error message.
    // A unit test to verify the step13 function when the distribute SALT rewards function fails in the liquidityRewardsEmitter. Ensure that it reverts with the correct error message.
    // A unit test to verify the step14 function when the DAO's POL balance is not sufficient for distribution. Ensure that it does not perform any distribution actions.
    // A unit test to verify the step15 function when the DAO vesting wallet's release operation fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step15 function when the DAO vesting wallet contains no SALT. Ensure that it does not perform any release actions.
    // A unit test to verify the step16 function when the team vesting wallet's release operation fails. Ensure that it reverts with the correct error message.
    // A unit test to verify the step16 function when the team vesting wallet contains no SALT. Ensure that it does not perform any release actions.
    // A unit test to verify the performUpkeep function when it is called before the previous call has finished. Ensure that it reverts with the correct error message.
	}
