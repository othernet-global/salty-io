// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../../dev/Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../../pools/PoolUtils.sol";
import "../Emissions.sol";


contract TestEmissions is Test, Deployment
	{
	address public alice = address(0x1111);
	address public bob = address(0x2222);

	bytes32 public pool1;
	bytes32 public pool2;


    function setUp() public
    	{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.prank(DEPLOYER);
			emissions = new Emissions( saltRewards, exchangeConfig, rewardsConfig );
			}

    	vm.startPrank( DEPLOYER );
    	IERC20 token1 = new TestERC20("TEST", 18);
		IERC20 token2 = new TestERC20("TEST", 18);
		IERC20 token3 = new TestERC20("TEST", 18);

        (pool1,) = PoolUtils.poolID(token1, token2);
        (pool2,) = PoolUtils.poolID(token2, token3);
		vm.stopPrank();

		// Whitelist pools
    	vm.startPrank( address(dao) );
		poolsConfig.whitelistPool(pools, token1, token2);
		poolsConfig.whitelistPool(pools, token2, token3);
		vm.stopPrank();

    	vm.startPrank( DEPLOYER );
		// Add SALT to the contract (for the emissions)
		salt.transfer(address(this), 1000 ether);

		// Send some SALT to alice and bob
		salt.transfer(alice, 100 ether);
		salt.transfer(bob, 100 ether);
		vm.stopPrank();

		vm.prank(alice);
		salt.approve( address(staking), type(uint256).max );

		vm.prank(bob);
		salt.approve( address(staking), type(uint256).max );

		// Increase emissionsWeeklyPercent to 1% weekly for testing (.50% default + 2x 0.25% increment)
    	vm.startPrank( address(dao) );
		rewardsConfig.changeEmissionsWeeklyPercent(true);
        rewardsConfig.changeEmissionsWeeklyPercent(true);
        vm.stopPrank();
    	}


	function pendingLiquidityRewardsForPool( bytes32 pool ) public view returns (uint256)
		{
		bytes32[] memory pools = new bytes32[](1);
		pools[0] = pool;

		return liquidityRewardsEmitter.pendingRewardsForPools( pools )[0];
		}


	function pendingStakingRewardsForPool( bytes32 pool ) public view returns (uint256)
		{
		bytes32[] memory pools = new bytes32[](1);
		pools[0] = pool;

		return stakingRewardsEmitter.pendingRewardsForPools( pools )[0];
		}


	function testPerformUpkeepOnlyCallableFromDAO() public
		{
		vm.expectRevert( "Emissions.performUpkeep is only callable from the Upkeep contract" );
        emissions.performUpkeep(2 weeks);

		vm.prank(address(upkeep));
        emissions.performUpkeep(2 weeks);
		}


	// A unit test to check the _performUpkeep function when the timeSinceLastUpkeep is zero. Verify that the function does not perform any actions.
	function testPerformUpkeepWithZeroTimeSinceLastUpkeep() public {

		// Transfer the initial rewards
        salt.transfer( address(emissions), 100 ether );

        // Call _performUpkeep function
        uint256 initialSaltBalance = salt.balanceOf(address(this));

		vm.prank(address(upkeep));
        emissions.performUpkeep(0);

        // Since timeSinceLastUpkeep was zero, no actions should be taken
        // Therefore, the SALT balance should be the same
        uint256 finalSaltBalance = salt.balanceOf(address(this));
        assertEq(initialSaltBalance, finalSaltBalance);
    }



	}
