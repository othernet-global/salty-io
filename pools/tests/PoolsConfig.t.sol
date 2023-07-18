// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../../Deployment.sol";
import "../../root_tests/TestERC20.sol";
import "../PoolsConfig.sol";
import "../PoolUtils.sol";


contract PoolsConfigTest is Deployment
	{
	IERC20 public token1 = new TestERC20(18);
	IERC20 public token2 = new TestERC20(18);
	IERC20 public token3 = new TestERC20(18);

    uint256 public originalNumWhitelisted;


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			{
			vm.prank(DEPLOYER);
			poolsConfig = new PoolsConfig();
			}
		}


    function setUp() public
    	{
    	vm.startPrank( DEPLOYER );

		originalNumWhitelisted = poolsConfig.numberOfWhitelistedPools();

        // Whitelist the pools
        poolsConfig.whitelistPool(token1, token2);
        poolsConfig.whitelistPool(token2, token3);
		vm.stopPrank();
		}


	// A unit test which tests the default values for the contract
	function testConstructor() public {
		assertEq(poolsConfig.maximumWhitelistedPools(), 50, "Incorrect maximumWhitelistedPools");
		assertEq(STAKED_SALT, bytes32(0), "Incorrect STAKED_SALT value");
	}


	// A unit test that tests maximumWhitelistedPools
	function testMaximumWhitelistedPools() public {
	uint256 numWhitelistedPools = poolsConfig.numberOfWhitelistedPools();

	vm.startPrank( DEPLOYER );

	uint256 numToAdd = poolsConfig.maximumWhitelistedPools() - numWhitelistedPools;
	for( uint256 i = 0; i < numToAdd; i++ )
		{
		IERC20 tokenA = new TestERC20(18);
		IERC20 tokenB = new TestERC20(18);

        poolsConfig.whitelistPool(tokenA, tokenB);
		}

	(bytes32 poolID,) = PoolUtils.poolID(token1, token3);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

	vm.expectRevert( "Maximum number of whitelisted pools already reached" );
    poolsConfig.whitelistPool(token1, token3);
    assertEq( poolsConfig.numberOfWhitelistedPools(), poolsConfig.maximumWhitelistedPools());
    }




	// A unit test that tests the whitelist function with valid input and confirms if the pool is added to the whitelist.
	function testWhitelistValidPool() public {
	vm.startPrank( DEPLOYER );

	(bytes32 poolID,) = PoolUtils.poolID(token1, token3);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

    poolsConfig.whitelistPool(token1, token3);
    assertTrue(poolsConfig.isWhitelisted(poolID), "New pool should be valid after whitelisting");
    }


	// A unit test that tests the whitelist function with an invalid input
	function testWhitelistInvalidPool() public {
	vm.startPrank( DEPLOYER );

	(bytes32 poolID,) = PoolUtils.poolID(token1, token1);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

	vm.expectRevert( "tokenA and tokenB cannot be the same token" );
    poolsConfig.whitelistPool(token1, token1);

    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should still not be valid");
    }


	// A unit test that tests the unwhitelist function with valid input and ensures the pool is removed from the whitelist.
	function testUnwhitelistValidPool() public {
	vm.startPrank( DEPLOYER );

    // Whitelist another pool for testing unwhitelist
	(bytes32 poolID,) = PoolUtils.poolID(token1, token3);
    poolsConfig.whitelistPool(token1, token3);

    // Ensure the pool is whitelisted
    assertTrue(poolsConfig.isWhitelisted(poolID));

    // Unwhitelist the test pool
    poolsConfig.unwhitelistPool(token1, token3);

    // Ensure the pool is no longer whitelisted
    assertFalse(poolsConfig.isWhitelisted(poolID));

	// Whitelist again
    poolsConfig.whitelistPool(token1, token3);
    assertTrue(poolsConfig.isWhitelisted(poolID));
    }


    // A unit test that tests the numberOfWhitelistedPools function and confirms if it returns the correct number of whitelisted pools.
	function testNumberOfWhitelistedPools() public {
	vm.startPrank( DEPLOYER );

    // Whitelist another pool
    poolsConfig.whitelistPool(token1, token3);

    // Test the numberOfWhitelistedPools function
    uint256 expectedNumberOfWhitelistedPools = originalNumWhitelisted + 3;
    uint256 actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);

	// Whitelist the same pool in reverse
    poolsConfig.whitelistPool(token3, token1);

    actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);

    // Whitelist another pool
    IERC20 token4 = new TestERC20(18);

    poolsConfig.whitelistPool(token3, token4);

    expectedNumberOfWhitelistedPools = originalNumWhitelisted + 4;
    actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);
    }


    // A unit test that tests the whitelistedPoolAtIndex function and verifies if it returns the correct pool at the given index.
    function testWhitelistedPoolAtIndex() public {
	vm.startPrank( DEPLOYER );

    bytes32 poolAtIndex0 = poolsConfig.whitelistedPoolAtIndex(originalNumWhitelisted + 0);
    (bytes32 expectedIndex0,) = PoolUtils.poolID(token1, token2);
    assertEq(poolAtIndex0, expectedIndex0, "Pool at index 0 is incorrect");

    bytes32 poolAtIndex1 = poolsConfig.whitelistedPoolAtIndex(originalNumWhitelisted + 1);
    (bytes32 expectedIndex1,) = PoolUtils.poolID(token2, token3);
    assertEq(poolAtIndex1, expectedIndex1, "Pool at index 1 is incorrect");
    }


    // A unit test that tests the isWhitelisted function with valid and invalid pools and confirms if it returns the correct boolean value for each case.
	function testIsValidPool() public {
		vm.startPrank( DEPLOYER );

        // Whitelist a new pool
    	poolsConfig.whitelistPool(token1, token3);

        // Test valid pools
        (bytes32 pool1,) = PoolUtils.poolID(token1, token2);
        (bytes32 extraPool,) = PoolUtils.poolID(token1, token3);

        assertTrue(poolsConfig.isWhitelisted(pool1), "first pool should be valid");
        assertTrue(poolsConfig.isWhitelisted(extraPool), "extraPool should be valid");
        assertTrue(poolsConfig.isWhitelisted(STAKED_SALT), "Staked SALT pool should be valid");

        // Test invalid pool
        bytes32 invalidPool = bytes32(uint256(0xDEAD));
        assertFalse(poolsConfig.isWhitelisted(invalidPool), "Invalid pool should not be valid");
    }


	// A unit test that tests the whitelistedPools function and ensures if it returns the correct list of whitelisted pools.
	function testWhitelistedPools() public {
	vm.startPrank( DEPLOYER );

    // Check initial state
    uint256 initialPoolCount = poolsConfig.numberOfWhitelistedPools();
    assertEq(initialPoolCount, originalNumWhitelisted + 2, "Initial whitelisted pool count is incorrect");

	// Whitelist a new pool
	poolsConfig.whitelistPool(token1, token3);

    // Check new state
    uint256 newPoolCount = poolsConfig.numberOfWhitelistedPools();
    assertEq(newPoolCount, originalNumWhitelisted + 3, "New whitelisted pool count is incorrect");

    // Verify whitelisted pools
	(bytes32 pool1,) = PoolUtils.poolID(token1, token2);
	(bytes32 pool1b,) = PoolUtils.poolID(token2, token1);
	assertEq( pool1, pool1b );

	(bytes32 pool2,) = PoolUtils.poolID(token2, token3);
	(bytes32 extraPool,) = PoolUtils.poolID(token1, token3);

    bytes32[] memory currentPools = poolsConfig.whitelistedPools();
    assertEq(currentPools.length, originalNumWhitelisted + 3, "Whitelisted pools length is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 0], pool1, "First whitelisted pool is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 1], pool2, "Second whitelisted pool is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 2], extraPool, "Third whitelisted pool is incorrect");
    }


	// A unit test that tests the function of underlyingTokenPair
	function testUnderlyingTokenPair() public {
	vm.startPrank( DEPLOYER );

	// Whitelist a new pool
	poolsConfig.whitelistPool(token1, token3);

    // Verify already whitelisted pools
	(bytes32 pool1,) = PoolUtils.poolID(token1, token2);
	(bytes32 pool2,) = PoolUtils.poolID(token2, token3);

	// And the newly whitelisted pool
	(bytes32 extraPool,) = PoolUtils.poolID(token1, token3);

	(IERC20 tokenA, IERC20 tokenB) = poolsConfig.underlyingTokenPair(pool1);
	assertEq(address(tokenA), address(token1));
	assertEq(address(tokenB), address(token2));

	(tokenA, tokenB) = poolsConfig.underlyingTokenPair(pool2);
	assertEq(address(tokenA), address(token2));
	assertEq(address(tokenB), address(token3));

	(tokenA, tokenB) = poolsConfig.underlyingTokenPair(extraPool);
	assertEq(address(tokenA), address(token1));
	assertEq(address(tokenB), address(token3));
    }

}