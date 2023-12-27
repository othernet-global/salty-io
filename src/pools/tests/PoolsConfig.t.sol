// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../dev/Deployment.sol";
import "../../pools/interfaces/IPoolStats.sol";


contract PoolsConfigTest is Deployment
	{
	IERC20 public token1 = new TestERC20("TEST", 18);
	IERC20 public token2 = new TestERC20("TEST", 18);
	IERC20 public token3 = new TestERC20("TEST", 18);

    uint256 public originalNumWhitelisted;


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();
		}


    function setUp() public
    	{
    	vm.startPrank( address(dao) );

		originalNumWhitelisted = poolsConfig.numberOfWhitelistedPools();

        // Whitelist the pools
        poolsConfig.whitelistPool( pools,   token1, token2);
        poolsConfig.whitelistPool( pools,   token2, token3);
		vm.stopPrank();
		}


	// A unit test which tests the default values for the contract
	function testConstructor() public {
		assertEq(poolsConfig.maximumWhitelistedPools(), 50, "Incorrect maximumWhitelistedPools");
		assertEq(poolsConfig.maximumInternalSwapPercentTimes1000(), 1000, "Incorrect maximumInternalSwapPercentTimes1000");
		assertEq(PoolUtils.STAKED_SALT, bytes32(0), "Incorrect STAKED_SALT value");
	}


	// A unit test that tests maximumWhitelistedPools
	function testMaximumWhitelistedPools() public {
	uint256 numWhitelistedPools = poolsConfig.numberOfWhitelistedPools();

	vm.startPrank( address(dao) );

	uint256 numToAdd = poolsConfig.maximumWhitelistedPools() - numWhitelistedPools;
	for( uint256 i = 0; i < numToAdd; i++ )
		{
		IERC20 tokenA = new TestERC20("TEST", 18);
		IERC20 tokenB = new TestERC20("TEST", 18);

        poolsConfig.whitelistPool( pools,   tokenA, tokenB);
		}

	bytes32 poolID = PoolUtils._poolID(token1, token3);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

	vm.expectRevert( "Maximum number of whitelisted pools already reached" );
    poolsConfig.whitelistPool( pools,   token1, token3);
    assertEq( poolsConfig.numberOfWhitelistedPools(), poolsConfig.maximumWhitelistedPools());
    }




	// A unit test that tests the whitelist function with valid input and confirms if the pool is added to the whitelist.
	function testWhitelistValidPool() public {
	vm.startPrank( address(dao) );

	bytes32 poolID = PoolUtils._poolID(token1, token3);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

    poolsConfig.whitelistPool( pools,   token1, token3);
    assertTrue(poolsConfig.isWhitelisted(poolID), "New pool should be valid after whitelisting");
    }


	// A unit test that tests the whitelist function with an invalid input
	function testWhitelistInvalidPool() public {
	vm.startPrank( address(dao) );

	bytes32 poolID = PoolUtils._poolID(token1, token1);
    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should not be valid yet");

	vm.expectRevert( "tokenA and tokenB cannot be the same token" );
    poolsConfig.whitelistPool( pools,   token1, token1);

    assertFalse(poolsConfig.isWhitelisted(poolID), "New pool should still not be valid");
    }


	// A unit test that tests the unwhitelist function with valid input and ensures the pool is removed from the whitelist.
	function testUnwhitelistValidPool() public {
	vm.startPrank( address(dao) );

    // Whitelist another pool for testing unwhitelist
	bytes32 poolID = PoolUtils._poolID(token1, token3);
    poolsConfig.whitelistPool( pools,   token1, token3);

    // Ensure the pool is whitelisted
    assertTrue(poolsConfig.isWhitelisted(poolID));

    // Unwhitelist the test pool
    poolsConfig.unwhitelistPool( pools, token1, token3);

    // Ensure the pool is no longer whitelisted
    assertFalse(poolsConfig.isWhitelisted(poolID));

	// Whitelist again
    poolsConfig.whitelistPool( pools,   token1, token3);
    assertTrue(poolsConfig.isWhitelisted(poolID));
    }


    // A unit test that tests the numberOfWhitelistedPools function and confirms if it returns the correct number of whitelisted pools.
	function testNumberOfWhitelistedPools() public {
	vm.startPrank( address(dao) );

    // Whitelist another pool
    poolsConfig.whitelistPool( pools,   token1, token3);

    // Test the numberOfWhitelistedPools function
    uint256 expectedNumberOfWhitelistedPools = originalNumWhitelisted + 3;
    uint256 actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);

	// Whitelist the same pool in reverse
    poolsConfig.whitelistPool( pools,   token3, token1);

    actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);

    // Whitelist another pool
    IERC20 token4 = new TestERC20("TEST", 18);

    poolsConfig.whitelistPool( pools,   token3, token4);

    expectedNumberOfWhitelistedPools = originalNumWhitelisted + 4;
    actualNumberOfWhitelistedPools = poolsConfig.numberOfWhitelistedPools();
    assertEq(expectedNumberOfWhitelistedPools, actualNumberOfWhitelistedPools);
    }


    // A unit test that tests the isWhitelisted function with valid and invalid pools and confirms if it returns the correct boolean value for each case.
	function testIsValidPool() public {
		vm.startPrank( address(dao) );

        // Whitelist a new pool
    	poolsConfig.whitelistPool( pools,   token1, token3);

        // Test valid pools
        bytes32 pool1 = PoolUtils._poolID(token1, token2);
        bytes32 extraPool = PoolUtils._poolID(token1, token3);

        assertTrue(poolsConfig.isWhitelisted(pool1), "first pool should be valid");
        assertTrue(poolsConfig.isWhitelisted(extraPool), "extraPool should be valid");
        assertTrue(poolsConfig.isWhitelisted(PoolUtils.STAKED_SALT), "Staked SALT pool should be valid");

        // Test invalid pool
        bytes32 invalidPool = bytes32(uint256(0xDEAD));
        assertFalse(poolsConfig.isWhitelisted(invalidPool), "Invalid pool should not be valid");
    }


	// A unit test that tests the whitelistedPools function and ensures if it returns the correct list of whitelisted pools.
	function testWhitelistedPools() public {
	vm.startPrank( address(dao) );

    // Check initial state
    uint256 initialPoolCount = poolsConfig.numberOfWhitelistedPools();
    assertEq(initialPoolCount, originalNumWhitelisted + 2, "Initial whitelisted pool count is incorrect");

	// Whitelist a new pool
	poolsConfig.whitelistPool( pools,   token1, token3);

    // Check new state
    uint256 newPoolCount = poolsConfig.numberOfWhitelistedPools();
    assertEq(newPoolCount, originalNumWhitelisted + 3, "New whitelisted pool count is incorrect");

    // Verify whitelisted pools
	bytes32 pool1 = PoolUtils._poolID(token1, token2);
	bytes32 pool1b = PoolUtils._poolID(token2, token1);
	assertEq( pool1, pool1b );

	bytes32 pool2 = PoolUtils._poolID(token2, token3);
	bytes32 extraPool = PoolUtils._poolID(token1, token3);

    bytes32[] memory currentPools = poolsConfig.whitelistedPools();
    assertEq(currentPools.length, originalNumWhitelisted + 3, "Whitelisted pools length is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 0], pool1, "First whitelisted pool is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 1], pool2, "Second whitelisted pool is incorrect");
    assertEq(currentPools[originalNumWhitelisted + 2], extraPool, "Third whitelisted pool is incorrect");
    }


	// A unit test that tests the function of underlyingTokenPair
	function testUnderlyingTokenPair() public {
	vm.startPrank( address(dao) );

	// Whitelist a new pool
	poolsConfig.whitelistPool( pools,   token1, token3);

    // Verify already whitelisted pools
	bytes32 pool1 = PoolUtils._poolID(token1, token2);
	bytes32 pool2 = PoolUtils._poolID(token2, token3);

	// And the newly whitelisted pool
	bytes32 extraPool = PoolUtils._poolID(token1, token3);

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


	// A unit test that tests the tokenHasBeenWhitelisted function when the token has not been whitelisted.
	function testTokenNotWhitelisted() public {
    	vm.startPrank( address(dao) );

    	IERC20 tokenNotWhitelisted = new TestERC20("TEST", 18);

        bool hasWhitelisted = poolsConfig.tokenHasBeenWhitelisted(tokenNotWhitelisted, wbtc, weth);
        assertFalse(hasWhitelisted, "Token should not be whitelisted");
    }


	// A unit test that tests the underlyingTokenPair function when one of the token addresses is 0x0
	function testUnderlyingTokenPairInvalidToken() public {
        vm.startPrank( address(dao) );

        // Generate a pool id with one of the tokens being 0x0
        bytes32 poolID = PoolUtils._poolID(token1, IERC20(address(0)));

        // Expect revert due to invalid pool id
        vm.expectRevert("This poolID does not exist");
        poolsConfig.underlyingTokenPair(poolID);

        vm.stopPrank();
    }



	// A unit test to ensure only owners can change the maximum number of pools that can be whitelisted
    function testChangeMaximumWhitelistedPools() public {
        uint256 initialMaxPools = poolsConfig.maximumWhitelistedPools();

        // Non-owner tries to increase the limit - should revert
        address nonOwner = address(0xDEAD);
        vm.startPrank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        poolsConfig.changeMaximumWhitelistedPools(true);
        vm.stopPrank();
        assertEq(poolsConfig.maximumWhitelistedPools(), initialMaxPools, "Non-owner should not be able to increase the limit");

        // Non-owner tries to decrease the limit - should revert
        vm.startPrank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        poolsConfig.changeMaximumWhitelistedPools(false);
        vm.stopPrank();
        assertEq(poolsConfig.maximumWhitelistedPools(), initialMaxPools, "Non-owner should not be able to decrease the limit");

        // Owner increases the limit
        vm.startPrank(address(dao));
        poolsConfig.changeMaximumWhitelistedPools(true);
        vm.stopPrank();
        assertEq(poolsConfig.maximumWhitelistedPools(), initialMaxPools + 10, "Owner should be able to increase the limit");

        // Owner decreases the limit
        vm.startPrank(address(dao));
        poolsConfig.changeMaximumWhitelistedPools(false);
        vm.stopPrank();
        assertEq(poolsConfig.maximumWhitelistedPools(), initialMaxPools, "Owner should be able to decrease the limit");
    }



    // A unit test that tests the whitelist function without proper permissions
    function testWhitelistPoolWithoutPermissions() public {

    	vm.expectRevert("Ownable: caller is not the owner");
        poolsConfig.whitelistPool( pools,   token1, token3);
    }



    // A unit test that tests the unwhitelist function without proper permissions
    function testUnwhitelistPoolWithoutPermissions() public {
    	vm.startPrank( address(dao) );
        bytes32 poolID = PoolUtils._poolID(token1, token3);
        poolsConfig.whitelistPool( pools,   token1, token3);
        assertTrue(poolsConfig.isWhitelisted(poolID), "New pool should be valid after whitelisting by owner");
    	 vm.stopPrank();

    	vm.expectRevert("Ownable: caller is not the owner");
        poolsConfig.unwhitelistPool( pools, token1, token3);
        assertTrue(poolsConfig.isWhitelisted(poolID), "Whitelisted pool should still be valid after attempted non-owner unwhitelisting");
    }


	// A unit test to confirm that tokenHasBeenWhitelisted returns false for both values if the pair ID doesn't reflect a whitelisted pair
    function testTokenHasBeenWhitelisted() public {
    	IERC20 fakeToken = new TestERC20("FAKE", 18);

    	// Check if the function returns false when the token is not whitelisted
    	assertFalse(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return false when the token is not whitelisted");

    	// Whitelist the fake token with WBTC, and check if the function returns true
    	vm.prank(address(dao));
    	poolsConfig.whitelistPool( pools,   fakeToken, wbtc);
    	assertTrue(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return true when the token is whitelisted with WBTC");

    	// Unwhitelist the fake token from WBTC, and check if the function returns false now
    	vm.prank(address(dao));
    	poolsConfig.unwhitelistPool( pools, fakeToken, wbtc);
    	assertFalse(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return false when the token is unwhitelisted from WBTC");

    	// Whitelist the fake token with WETH, and check if the function returns true
    	vm.prank(address(dao));
    	poolsConfig.whitelistPool( pools,   fakeToken, weth);
    	assertTrue(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return true when the token is whitelisted with WETH");

    	// Unwhitelist the fake token from WETH, and check if the function returns false now
    	vm.prank(address(dao));
    	poolsConfig.unwhitelistPool( pools, fakeToken, weth);
    	assertFalse(poolsConfig.tokenHasBeenWhitelisted(fakeToken, wbtc, weth), "Function should return false when the token is unwhitelisted from WETH");
    }


	// A unit test that checks that underlyingTokenPair reverts for unwhitelisted poolID
	    function testUnderlyingTokenPairReverts() public {
            vm.expectRevert("This poolID does not exist");
            poolsConfig.underlyingTokenPair(bytes32(0x0));
        }


	// A unit test that tests tokenHasBeenWhitelisted function when tokenA or tokenB is wbtc or weth
	function testTokenHasBeenWhitelisted2() public {

        // Test tokens that have been whitelisted
        assertTrue(poolsConfig.tokenHasBeenWhitelisted(weth, wbtc, weth), "newTokenA should be whitelisted");
        assertTrue(poolsConfig.tokenHasBeenWhitelisted(wbtc, wbtc, weth), "newTokenB should be whitelisted");
    }


    // A unit test that checks the contract’s behavior when a non-existent pool is queried through underlyingTokenPair
	function testNonExistentPoolUnderlyingTokenPair() public {
        // Choose arbitrary non-existent poolID (not whitelisted)
        bytes32 nonExistentPoolID = keccak256("nonexistent");

        // Expect revert for querying non-existent pool
        vm.expectRevert("This poolID does not exist");
        poolsConfig.underlyingTokenPair(nonExistentPoolID);
    }


    // A unit test that ensures that staked SALT pool can always be queried as whitelisted even if not explicitly added to _whitelist
	function testStakedSALTPoolAlwaysWhitelisted() public {
        // Querying if the staked SALT pool is whitelisted should always return true regardless of _whitelist content.
        assertEq(poolsConfig.isWhitelisted(PoolUtils.STAKED_SALT), true, "Staked SALT pool should always be whitelisted");
    }


    // A unit test that verifies the behavior of isWhitelisted for pools that were never whitelisted or after they have been unwhitelisted
	function testIsWhitelistedBehaviorForNeverWhitelistedOrUnwhitelistedPools() public {
        vm.startPrank(address(dao));

        // Create new token for testing and make sure it's not whitelisted
        IERC20 newTokenA = new TestERC20("NEWTEST", 18);
        IERC20 newTokenB = new TestERC20("NEWTEST", 18);
        bytes32 newPoolID = PoolUtils._poolID(newTokenA, newTokenB);
        assertFalse(poolsConfig.isWhitelisted(newPoolID), "Newly created pool should not be whitelisted");

        // Whitelist new pool and check
        poolsConfig.whitelistPool( pools, newTokenA, newTokenB);
        assertTrue(poolsConfig.isWhitelisted(newPoolID), "Pool should be whitelisted after calling whitelistPool()");

        // Unwhitelisting new pool and check
        poolsConfig.unwhitelistPool(pools, newTokenA, newTokenB);
        assertFalse(poolsConfig.isWhitelisted(newPoolID), "Pool should not be whitelisted after being unwhitelisted");

        // Check if an arbitrary non-existing pool id is not whitelisted
        bytes32 arbitraryPoolID = PoolUtils._poolID(IERC20(address(1)), IERC20(address(2)));
        assertFalse(poolsConfig.isWhitelisted(arbitraryPoolID), "Arbitrary non-existing pool should not be whitelisted");

        vm.stopPrank();
    }


	// The index of pool tokenA/tokenB within the whitelistedPools array.
	// Should always find a value as only whitelisted pools are used in the arbitrage path.
	function _poolIndex( IERC20 tokenA, IERC20 tokenB, bytes32[] memory poolIDs ) internal pure returns (uint64 index)
		{
		bytes32 poolID = PoolUtils._poolID( tokenA, tokenB );

		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			if (poolID == poolIDs[i])
				return uint64(i);
			}

		// poolIndex lookup failure
		return type(uint64).max;
		}


	// Check that all the cached arbitrage indicies are correct
	function _checkArbitrageIndicies() public
		{
		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();

		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			bytes32 poolID = poolIDs[i];

			(IERC20 arbToken2, IERC20 arbToken3) = poolsConfig.underlyingTokenPair(poolID);

			// The middle two tokens can never be WETH in a valid arbitrage path as the path is WETH->arbToken2->arbToken3->WETH.
			if ( (arbToken2 != weth) && (arbToken3 != weth) )
				{
				uint64 poolIndex1 = _poolIndex( weth, arbToken2, poolIDs );
				uint64 poolIndex2 = _poolIndex( arbToken2, arbToken3, poolIDs );
				uint64 poolIndex3 = _poolIndex( arbToken3, weth, poolIDs );

				// Check if the indicies in storage have the correct values
				IPoolStats.ArbitrageIndicies memory indicies = pools.arbitrageIndicies(poolID);

				assertTrue( ( poolIndex1 == indicies.index1 ) && ( poolIndex2 == indicies.index2 ) && ( poolIndex3 == indicies.index3 ) );

//					console.log( poolIndex1, indicies.index1 );
//					console.log( poolIndex2, indicies.index2 );
//					console.log( poolIndex3, indicies.index3 );
				}
			}
		}


    // A unit test that makes sure the updateArbitrageIndicies function in the pools contract is called when the whitelist is changed
    function testPoolWhitelistChangesUpdatesArbitrageIndices() public {
        vm.startPrank(address(dao));

		_checkArbitrageIndicies();


		// Whitelisting a pool will change the pool indicies
        poolsConfig.whitelistPool( pools, token1, token3);
        assertTrue(poolsConfig.isWhitelisted(PoolUtils._poolID(token1, token3)), "token1/token3 should be whitelisted");
		_checkArbitrageIndicies();

		// Unwhitelisting a pool will change the pool indicies
        poolsConfig.unwhitelistPool( pools, token2, token3);
        assertFalse(poolsConfig.isWhitelisted(PoolUtils._poolID(token2, token3)), "token2/token3 should be unwhitelisted");
		_checkArbitrageIndicies();
    }


    // A unit test that ensures the underlyingPoolTokens mapping is correctly updated when pools are whitelisted or unwhitelisted
    function testUnderlyingPoolTokensAreCorrectlyUpdated() public {
        vm.startPrank(address(dao));

        // Whitelist new pools and check the mapping is updated
        bytes32 newPoolID1 = PoolUtils._poolID(token1, token3);
        assertFalse(poolsConfig.isWhitelisted(newPoolID1), "Pool should not be whitelisted before calling whitelistPool");
        poolsConfig.whitelistPool(pools, token1, token3);
        assertTrue(poolsConfig.isWhitelisted(newPoolID1), "Pool should be whitelisted");
        (IERC20 updatedTokenA, IERC20 updatedTokenB) = poolsConfig.underlyingTokenPair(newPoolID1);
        assertEq(address(updatedTokenA), address(token1), "underlyingPoolTokens mapping did not update tokenA correctly");
        assertEq(address(updatedTokenB), address(token3), "underlyingPoolTokens mapping did not update tokenB correctly");

        // Unwhitelist a pool and check the mapping is updated
        bytes32 poolToRemoveID = PoolUtils._poolID(token1, token2);
        assertTrue(poolsConfig.isWhitelisted(poolToRemoveID), "Pool should be whitelisted before calling unwhitelistPool");
        poolsConfig.unwhitelistPool(pools, token1, token2);
        assertFalse(poolsConfig.isWhitelisted(poolToRemoveID), "Pool should not be whitelisted after calling unwhitelistPool");

		vm.expectRevert("This poolID does not exist");
        (updatedTokenA, updatedTokenB) = poolsConfig.underlyingTokenPair(poolToRemoveID);

        vm.stopPrank();
    }
}