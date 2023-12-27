// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "./ITestUpkeep.sol";


contract TestUpkeepEdge is Deployment
	{
    address public constant alice = address(0x1111);


	constructor()
		{
		initializeContracts();

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


	// A unit test to check the behavior of performUpkeep() when the priceAggregator returns zero price
	function testPerformUpkeepZeroPrice() public
		{
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

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 0 );
		forcedPriceFeed.setETHPrice( 0 );
		vm.stopPrank();

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================
		}



    // A unit test to verify the step2 function when the DAO's WETH balance is zero.
	function testStep2() public
		{
		// Step 2. Withdraws existing WETH arbitrage profits from the Pools contract and rewards the caller of performUpkeep() with default 5% of the withdrawn amount.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step2(alice);

    	assertEq( weth.balanceOf(alice), 0 ether );
		}


    // A unit test to verify the steps 3-5 function when the remaining WETH balance in the contract is zero.
	function testStep3Through5() public
		{
		vm.startPrank(address(upkeep));
		ITestUpkeep(address(upkeep)).step3();
		ITestUpkeep(address(upkeep)).step4();
		ITestUpkeep(address(upkeep)).step5();
		vm.stopPrank();

		assertEq( collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usds)), 0 );
		assertEq( collateralAndLiquidity.userShareForPool(address(dao), PoolUtils._poolID(usds, dai)), 0 );
		}


    // A unit test to verify the step5 function when the Emissions' performUpkeep function does not emit any SALT. Ensure that it does not perform any emission actions.
	function testStep6() public
		{
		assertEq( salt.balanceOf(address(emissions)), 52 * 1000000 ether );

		vm.warp( upkeep.lastUpkeepTimeEmissions() );

		// Step 6. Sends SALT Emissions to the SaltRewards contract.
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step6();

		// Emissions initial distribution of 52 million tokens stored in the contract is a default .50% per week.
		assertEq( salt.balanceOf(address(saltRewards)), 0 );
		}


    // A unit test to verify the step9 function when the profits for pools are zero. Ensure that the function does not perform any actions.
    function testStep9() public
    	{
		bytes32[] memory poolIDs = new bytes32[](4);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usds);

		uint256 initialSupply = salt.totalSupply();

		// Step 9. Collects SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL), sends 10% to the initial dev team and burns a default 50% of the remaining - the rest stays in the DAO.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step9();

		// Check teamWallet transfer
		assertEq( salt.balanceOf(teamWallet), 0 ether);

		// Check the amount burned
		uint256 amountBurned = initialSupply - salt.totalSupply();
		uint256 expectedAmountBurned = 0;
		assertEq( amountBurned, expectedAmountBurned );
	  	}


    // A unit test to verify the step11 function when the dao's vesting wallet has no elapsed time
	function testSuccessStep10() public
		{
		// Warp to the start of when the teamVestingWallet starts to emit
		vm.warp( daoVestingWallet.start() );

		assertEq( salt.balanceOf(address(dao)), 0 );

		// Step 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step10();

		// Check that SALT has been sent to DAO.
		assertEq( salt.balanceOf(address(dao)), 0 );
		}


    // A unit test to verify the step11 function when the team's vesting wallet has no elapsed time
	function testSuccessStep11() public
		{
		// Warp to the start of when the teamVestingWallet starts to emit
		vm.warp( teamVestingWallet.start() );

		assertEq( salt.balanceOf(teamWallet), 0 );

		// Step 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step11();

		// Check that SALT has been sent to DAO.
		assertEq( salt.balanceOf(teamWallet), 0 );
		}
	}




