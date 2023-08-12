// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../Pools.sol";
import "../../dev/Deployment.sol";
import "../PoolStats.sol";
import "../PoolUtils.sol";
import "../../root_tests/TestERC20.sol";


contract TestPoolStats is Test, PoolStats
	{
	Deployment public deployment = new Deployment();

	IERC20 public tokenA = new TestERC20(6);
	IERC20 public tokenB = new TestERC20(18);
	IERC20 public tokenC = new TestERC20(18);

	bytes32 public poolID;
	bytes32 public poolID2;


	constructor()
		{
		// Different decimals
		(poolID,) = PoolUtils.poolID( tokenA, tokenB );

		// Same decimals
		(poolID2,) = PoolUtils.poolID( tokenB, tokenC );
		}


	// A unit test to determine that the initial alpha is calculated correctly (about 0.0011104942 for 30 minutes)
	function testConstants() public
		{
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( alpha, ABDKMathQuad.fromUInt(10**18)) ), 1110494169905607 );
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( ONE, ABDKMathQuad.fromUInt(10**18)) ), 1000000000000000000 );
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( ZERO, ABDKMathQuad.fromUInt(10**18)) ), 0 );
		}


	// A unit test where a single pool is updated multiple times, with varying reserve0 and reserve1 values. This test should verify that the averageReserveRatios and lastUpdateTimes are updated correctly. Specifically, the test should check that the exponential moving average calculation is correct, and that the last update time is set to the current block timestamp.
	function testUpdatePoolStatsMultipleTimes() public
    	{
		bytes16 actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 0 );

   		_updatePoolStats(poolID, 1 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 500000000000000000 );
   		assertEq( lastUpdateTimes[poolID], block.timestamp );

		// No delay in time has no effect on the average
   		_updatePoolStats(poolID, 2 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 500000000000000000 );
   		assertEq( lastUpdateTimes[poolID], block.timestamp );

		vm.warp( block.timestamp + 30 seconds );

   		_updatePoolStats(poolID, 2 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 516657412548584119 );
  		assertEq( lastUpdateTimes[poolID], block.timestamp );

		vm.warp( block.timestamp + 5 minutes );

   		_updatePoolStats(poolID, 10 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 3676016408923292353 );
  		assertEq( lastUpdateTimes[poolID], block.timestamp );

		vm.warp( block.timestamp + 15 minutes );

   		_updatePoolStats(poolID, 10 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 9996488626545765292 );
  		assertEq( lastUpdateTimes[poolID], block.timestamp );

		vm.warp( block.timestamp + 30 minutes );

		// Large delay will cause the effective alpha to max at 1 and ignore all previous data
   		_updatePoolStats(poolID, 20 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 20000000000000000000 );
  		assertEq( lastUpdateTimes[poolID], block.timestamp );

//		console.log( "Ratio: ", ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ) );
    	}


	// A unit test where a single pool is updated multiple times, with varying reserve0 and reserve1 values. This test should verify that the averageReserveRatios and lastUpdateTimes are updated correctly. Specifically, the test should check that the exponential moving average calculation is correct, and that the last update time is set to the current block timestamp.
	function testUpdatePoolStatsMultipleTimes2() public
    	{
		bytes16 actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 0 );

   		_updatePoolStats(poolID2, 1 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 500000000000000000 );
   		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		// No delay in time has no effect on the average
   		_updatePoolStats(poolID2, 2 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 500000000000000000 );
   		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		vm.warp( block.timestamp + 30 seconds );

   		_updatePoolStats(poolID2, 2 ether, 2 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 516657412548584119 );
  		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		vm.warp( block.timestamp + 5 minutes );

   		_updatePoolStats(poolID2, 10 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 3676016408923292353 );
  		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		vm.warp( block.timestamp + 15 minutes );

   		_updatePoolStats(poolID2, 10 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 9996488626545765292 );
  		assertEq( lastUpdateTimes[poolID2], block.timestamp );

		vm.warp( block.timestamp + 30 minutes );

		// Large delay will cause the effective alpha to max at 1 and ignore all previous data
   		_updatePoolStats(poolID2, 20 ether, 1 ether);
		actualRatio = averageReserveRatios[poolID2];
		assertEq( ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ), 20000000000000000000 );
  		assertEq( lastUpdateTimes[poolID2], block.timestamp );

//		console.log( "Ratio: ", ABDKMathQuad.toUInt( ABDKMathQuad.mul( actualRatio, ABDKMathQuad.fromUInt(10**18)) ) );
    	}


    }

