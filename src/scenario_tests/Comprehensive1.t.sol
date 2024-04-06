// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "../launch/BootstrapBallot.sol";


contract TestComprehensive1 is Deployment
	{
	// User wallets for testing
    address public constant alice = address(0x1111);
    address public constant bob = address(0x2222);
    address public constant charlie = address(0x3333);
    address public constant delta = address(0x4444);


    function setUp() public
		{
		initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();


		// Give some WBTC and WETH to Alice, Bob and Charlie
		vm.startPrank(DEPLOYER);
		wbtc.transfer(alice, 1000 * 10**8 );
		wbtc.transfer(bob, 1000 * 10**8 );
		wbtc.transfer(charlie, 1000 * 10**8 );

		weth.transfer(alice, 1000 ether);
		weth.transfer(bob, 1000 ether);
		weth.transfer(charlie, 1000 ether);

		usdc.transfer(alice, 1000 * 10**6 );
		usdc.transfer(bob, 1000 * 10**6 );
		usdc.transfer(charlie, 1000 * 10**6 );
		vm.stopPrank();

		// Everyone approves
		vm.startPrank(alice);
		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		salt.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();

		vm.startPrank(bob);
		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		salt.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();

		vm.startPrank(charlie);
		salt.approve(address(pools), type(uint256).max);
		wbtc.approve(address(pools), type(uint256).max);
		weth.approve(address(pools), type(uint256).max);
		salt.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);
		vm.stopPrank();
		}


	function testComprehensive() public
		{
		// Cast votes for the BootstrapBallot so that the initialDistribution can happen
		bytes memory sig = abi.encodePacked(aliceVotingSignature);
		vm.startPrank(alice);
		bootstrapBallot.vote(true, 1000 ether, sig);
		vm.stopPrank();

		sig = abi.encodePacked(bobVotingSignature);
		vm.startPrank(bob);
		bootstrapBallot.vote(true, 1000 ether, sig);
		vm.stopPrank();

		sig = abi.encodePacked(charlieVotingSignature);
		vm.startPrank(charlie);
		bootstrapBallot.vote(false, 1000 ether, sig);
		vm.stopPrank();

		// Finalize the ballot to distribute SALT to the protocol contracts and start up the exchange
		vm.warp( bootstrapBallot.claimableTimestamp1() );
		bootstrapBallot.finalizeBallot();

		// Wait a day so that alice, bob and charlie receive some SALT emissions for their xSALT
		vm.warp( block.timestamp + 1 days );

		vm.prank(alice);
		airdrop1.claim();
		vm.prank(bob);
		airdrop1.claim();
		vm.prank(charlie);
		airdrop1.claim();

		assertEq( salt.balanceOf(alice), 2747252747252747252 );
		assertEq( salt.balanceOf(bob), 2747252747252747252 );
		assertEq( salt.balanceOf(charlie), 2747252747252747252 );

		upkeep.performUpkeep();

		// No liquidity exists yet

		// Alice adds some SALT/WETH, AND SALT/USDC
		vm.startPrank(alice);
		salt.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		usdc.approve(address(liquidity), type(uint256).max);

		liquidity.depositLiquidityAndIncreaseShare(salt, weth, 1 ether, 10 ether, 0, 0, 0, block.timestamp, false);
		liquidity.depositLiquidityAndIncreaseShare(salt, usdc, 1 ether, 10 * 10**6, 0, 0, 0, block.timestamp, false);
		vm.stopPrank();

		// Bob adds some WBTC/WETH liquidity
		vm.startPrank(bob);
		salt.approve(address(liquidity), type(uint256).max);
		weth.approve(address(liquidity), type(uint256).max);
		wbtc.approve(address(liquidity), type(uint256).max);
		usdc.approve(address(liquidity), type(uint256).max);

    	liquidity.depositLiquidityAndIncreaseShare(usdc, weth, 1000 * 10**6, 1000 ether, 0, 0, 0, block.timestamp, false);
    	vm.stopPrank();

    	console.log( "bob USDC: ", usdc.balanceOf(bob) );

    	// Charlie places some trades
    	vm.startPrank(charlie);
    	uint256 amountOut1 = pools.depositSwapWithdraw(weth, salt, 1 ether, 0, block.timestamp);
    	rollToNextBlock();
    	uint256 amountOut2 = pools.depositSwapWithdraw(weth, salt, 1 ether, 0, block.timestamp);
		rollToNextBlock();
		vm.stopPrank();

		console.log( "ARBITRAGE PROFITS: ", pools.depositedUserBalance( address(dao), salt ) );

    	console.log( "charlie swapped SALT:", amountOut1 );
    	console.log( "charlie swapped SALT:", amountOut2 );

		console.log( "CURRENT REWARDS FOR CALLING: ", upkeep.currentRewardsForCallingPerformUpkeep() );

    	vm.warp( block.timestamp + 1 hours );

    	vm.prank(delta);
    	upkeep.performUpkeep();

    	console.log( "delta BALANCE: ", salt.balanceOf(address(delta)) );
    	}
	}
