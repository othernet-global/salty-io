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
		vm.roll(block.number + 1);
		pools.depositSwapWithdraw(salt, wbtc, 1 ether, 0, block.timestamp);
		vm.roll(block.number + 1);
		pools.depositSwapWithdraw(weth, wbtc, 1 ether, 0, block.timestamp);
		vm.roll(block.number + 1);
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


	// A unit test to check the behavior of performUpkeep() when the priceAggregator returns zero price
	function testPerformUpkeepZeroPrice() public
		{
		_setupLiquidity();
		_generateArbitrageProfits(false);

    	// Mimic arbitrage profits deposited as WETH for the DAO
    	vm.prank(DEPLOYER);
    	weth.transfer(address(dao), 100 ether);

    	vm.startPrank(address(dao));
    	weth.approve(address(pools), 100 ether);
    	pools.deposit(weth, 100 ether);
    	vm.stopPrank();

		assertEq( salt.balanceOf(address(stakingRewardsEmitter)), 3000000000000000000000005 );
		assertEq( salt.balanceOf(address(staking)), 0 );

		assertEq( upkeep.currentRewardsForCallingPerformUpkeep(), 5000049714925620913 );

		// Set a new price
		vm.startPrank(DEPLOYER);
		forcedPriceFeed.setBTCPrice( 0 );
		forcedPriceFeed.setETHPrice( 0 );
		vm.stopPrank();

		skip( 1 hours );

		// === Perform upkeep ===
		address upkeepCaller = address(0x9999);

		vm.prank(upkeepCaller);
		upkeep.performUpkeep();
		// ==================
		}



    // A unit test to verify the step1 function when the DAO's WETH balance is zero.
	function testStep1() public
		{
		// Step 1. Withdraws existing WETH arbitrage profits from the Pools contract and rewards the caller of performUpkeep() with default 5% of the withdrawn amount.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step1(alice);

    	assertEq( weth.balanceOf(alice), 0 ether );
		}


    // A unit test to verify the steps 2-3 function when the remaining WETH balance in the contract is zero.
	function testStep2Through3() public
		{
		vm.startPrank(address(upkeep));
		ITestUpkeep(address(upkeep)).step2();
		ITestUpkeep(address(upkeep)).step3();
		vm.stopPrank();

		assertEq( liquidity.userShareForPool(address(dao), PoolUtils._poolID(salt, usdc)), 0 );
		}


    // A unit test to verify the step4 function when the Emissions' performUpkeep function does not emit any SALT. Ensure that it does not perform any emission actions.
	function testStep4() public
		{
		assertEq( salt.balanceOf(address(emissions)), 52 * 1000000 ether );

		vm.warp( upkeep.lastUpkeepTimeEmissions() );

		// Step 4. Sends SALT Emissions to the SaltRewards contract.
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step4();

		// Emissions initial distribution of 50 million tokens stored in the contract is a default .50% per week.
		assertEq( salt.balanceOf(address(saltRewards)), 0 );
		}


    // A unit test to verify the step7 function when the profits for pools are zero. Ensure that the function does not perform any actions.
    function testStep7() public
    	{
		bytes32[] memory poolIDs = new bytes32[](4);
		poolIDs[0] = PoolUtils._poolID(salt,weth);
		poolIDs[1] = PoolUtils._poolID(salt,wbtc);
		poolIDs[2] = PoolUtils._poolID(wbtc,weth);
		poolIDs[3] = PoolUtils._poolID(salt,usdc);

		uint256 initialSupply = salt.totalSupply();

		// Step 7. Collects SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDC from formed POL), sends 10% to the initial dev team and burns a default 50% of the remaining - the rest stays in the DAO.
    	vm.prank(address(upkeep));
    	ITestUpkeep(address(upkeep)).step7();

		// Check teamWallet transfer
		assertEq( salt.balanceOf(teamWallet), 0 ether);

		// Check the amount burned
		uint256 amountBurned = initialSupply - salt.totalSupply();
		uint256 expectedAmountBurned = 0;
		assertEq( amountBurned, expectedAmountBurned );
	  	}


    // A unit test to verify the step8 function when the dao's vesting wallet has no elapsed time
	function testSuccessStep8() public
		{
		// Warp to the start of when the teamVestingWallet starts to emit
		vm.warp( daoVestingWallet.start() );

		assertEq( salt.balanceOf(address(dao)), 0 );

		// Step 8. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step8();

		// Check that SALT has been sent to DAO.
		assertEq( salt.balanceOf(address(dao)), 0 );
		}


    // A unit test to verify the step9 function when the team's vesting wallet has no elapsed time
	function testSuccessStep9() public
		{
		// Warp to the start of when the teamVestingWallet starts to emit
		vm.warp( teamVestingWallet.start() );

		assertEq( salt.balanceOf(teamWallet), 0 );

		// Step 9. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).
		vm.prank(address(upkeep));
		ITestUpkeep(address(upkeep)).step9();

		// Check that SALT has been sent to DAO.
		assertEq( salt.balanceOf(teamWallet), 0 );
		}
	}




