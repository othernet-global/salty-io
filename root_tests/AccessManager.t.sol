// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";
import "../AccessManager.sol";


contract TestAccessManager is Deployment, Test
	{
	constructor()
		{
		accessManager = new AccessManager(dao);
		}


	// A unit test where the DAO address is set to address(0) upon contract creation to ensure that it reverts as expected.
	function testCreateAccessManagerWithZeroAddress() public
    	{
    	IDAO zeroAddressDAO = IDAO(address(0));

    	vm.expectRevert("_dao cannot be address(0)");
    	new AccessManager(zeroAddressDAO);
    	}


	// A unit test where a user does not grant access and the walletHasAccess is checked to verify that the user does not have access.
	function testUserWithoutAccess( address user ) public
    	{
    	bool access = accessManager.walletHasAccess(user);
    	assertFalse(access, "User without granted access should not have access");
    	}


	// A unit test in which a DAO is used to initialize the AccessManager contract. Check that the dao state variable in the AccessManager contract is correctly set to the address of the DAO contract.
	function testDaoAddressInAccessManager() public
    	{
    	// Initialize new AccessManager with the DAO contract
    	AccessManager newAccessManager = new AccessManager(dao);

    	// Check that the dao state variable in the AccessManager contract is correctly set to the address of the DAO contract
    	assertEq(address(newAccessManager.dao()), address(dao), "DAO address not correctly set in AccessManager");
    	}


	// A  unit test where the DAO tries to call excludedCountriesUpdated and the geoVersion is checked before and after the function call to ensure it increments correctly.
	function testDaoCallsExcludedCountriesUpdated() public
    	{
    	// Get the initial geoVersion
    	uint256 initialGeoVersion = accessManager.geoVersion();

    	// DAO calls excludedCountriesUpdated
    	vm.prank(address(dao));
    	accessManager.excludedCountriesUpdated();

    	// Get the new geoVersion
    	uint256 newGeoVersion = accessManager.geoVersion();

    	// Check that the geoVersion incremented correctly
    	assertEq(newGeoVersion, initialGeoVersion + 1, "geoVersion did not increment correctly");
    	}


	// A unit test where an address other than the DAO tries to call excludedCountriesUpdated to ensure it reverts as expected.
	function testNonDaoCallsExcludedCountriesUpdated() public
    	{
    	// Non-DAO address tries to call excludedCountriesUpdated
    	IDAO fakeDAO = IDAO(address(this));
    	accessManager = new AccessManager(fakeDAO);

		// Shouldn't revert
    	accessManager.excludedCountriesUpdated();

		// Should revert
    	vm.expectRevert("Only the DAO can call excludedCountriesUpdated");

		vm.prank( address(0x123));
    	accessManager.excludedCountriesUpdated();
    	}


	// A unit test where a user grants access to their wallet using grantAccess, and walletHasAccess is called to verify that the access was correctly granted.
	function testGrantAccess() public
    	{
    	address user = address(this);

    	// User grants access to their wallet
    	accessManager.grantAccess();

    	// Check that the access was correctly granted
    	bool access = accessManager.walletHasAccess(user);
    	assertEq(access, true, "Access not correctly granted");
    	}


	// A unit test where a user grants access, then attempts to grant access again, and walletHasAccess is checked to verify that the user still has access and the function call does not revert.
	function testGrantAccessTwice() public
    	{
    	address user = address(this);

    	// User grants access to their wallet
    	accessManager.grantAccess();

    	// User attempts to grant access again
    	accessManager.grantAccess();

    	// Check that the user still has access
    	bool access = accessManager.walletHasAccess(user);
    	assertEq(access, true, "Access not correctly granted after granting access twice");
    	}


	// A unit test where a user grants access, the DAO calls excludedCountriesUpdated, then the user grants access again, and walletHasAccess is checked to verify that the user has access under the new geoVersion.
	function testAccessWithGeoVersionUpdate() public
		{
		address user = address(this);

		// User grants access to their wallet
		accessManager.grantAccess();

		// DAO updates the list of excluded countries
		vm.prank(address(dao));
		accessManager.excludedCountriesUpdated();

		// User grants access again
		accessManager.grantAccess();

		// Check that the user still has access under the new geoVersion
		bool access = accessManager.walletHasAccess(user);
		assertEq(access, true, "Access not correctly granted after geoVersion update");
		}


	// A unit test where the DAO calls excludedCountriesUpdated, a user grants access, the DAO calls excludedCountriesUpdated again, and walletHasAccess is checked to verify that the user does not have access under the new geoVersion.
	function testAccessRevocationWithGeoVersionUpdate() public
    	{
    	address user = address(this);

    	// DAO updates the list of excluded countries
		vm.prank(address(dao));
    	accessManager.excludedCountriesUpdated();

    	// User grants access to their wallet
    	accessManager.grantAccess();

    	// DAO updates the list of excluded countries again
		vm.prank(address(dao));
    	accessManager.excludedCountriesUpdated();

    	// Check that the user does not have access under the new geoVersion
    	bool access = accessManager.walletHasAccess(user);
    	assertEq(access, false, "Access incorrectly granted after geoVersion update");
    	}



	// A unit test where multiple users grant access, the DAO calls excludedCountriesUpdated, some users grant access again, and walletHasAccess is checked for each user to verify that the ones who granted access again have access under the new geoVersion, and the others do not.
	function testAccessStatusAfterMultipleUpdates() public
    	{
    	address user1 = address(0x1111);
    	address user2 = address(0x2222);
    	address user3 = address(0x3333);

    	// Users grant access to their wallets
    	vm.prank(user1);
    	accessManager.grantAccess();
    	vm.prank(user2);
    	accessManager.grantAccess();
    	vm.prank(user3);
    	accessManager.grantAccess();


    	// DAO updates the list of excluded countries
    	vm.prank(address(dao));
    	accessManager.excludedCountriesUpdated();

    	// Some users grant access to their wallets again
    	vm.prank(user1);
    	accessManager.grantAccess();
    	vm.prank(user3);
    	accessManager.grantAccess();

    	// Check that the users who granted access again have access under the new geoVersion
    	assertEq(accessManager.walletHasAccess(user1), true, "User1 should have access");
    	assertEq(accessManager.walletHasAccess(user3), true, "User3 should have access");

    	// Check that the user who did not grant access again does not have access under the new geoVersion
    	assertEq(accessManager.walletHasAccess(user2), false, "User2 should not have access");
    	}

    }

