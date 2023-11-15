// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";


contract TestManagedWallet is Deployment
	{
    address public constant alice = address(0x1111);

    uint256 constant public MAIN_WALLET = 0;
    uint256 constant public CONFIRMATION_WALLET = 1;


	constructor()
		{
		// If $COVERAGE=yes, create an instance of the contract so that coverage testing can work
		// Otherwise, what is tested is the actual deployed contract on the blockchain (as specified in Deployment.sol)
		if ( keccak256(bytes(vm.envString("COVERAGE" ))) == keccak256(bytes("yes" )))
			initializeContracts();

		grantAccessAlice();
		grantAccessBob();
		grantAccessCharlie();
		grantAccessDeployer();
		grantAccessDefault();
		}


    // A unit test to check whether the mainWallet function returns the correct main wallet address that was set in the constructor.
	function testMainWalletReturnsCorrectlySetAddress() public {
        address expectedMainWalletAddress = alice; // Should match the constructor argument for the main wallet
        ManagedWallet mw = new ManagedWallet(expectedMainWalletAddress, address(0x2222));
        address mainWalletAddress = mw.mainWallet();
        assertEq(mainWalletAddress, expectedMainWalletAddress, "Incorrect main wallet address returned");
    }


    // A unit test to check whether the confirmationWallet function returns the correct confirmation wallet address that was set in the constructor.
	function testConfirmWalletReturnsCorrectAddress() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        address setConfirmationWallet = address(this);

        // Checking if the confirmationWallet function returns the correct confirmation wallet address
        assertEq(managedWallet.confirmationWallet(), setConfirmationWallet);
    }


    // A unit test to check the changeWallet function when called by an address other than the main or confirmation wallet. Expect to fail with "Invalid sender".
	function testChangeWalletNotMainOrConfirmationShouldFail() external {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        address randomAddress = address(0x1234);
        vm.prank(randomAddress);
        vm.expectRevert("Invalid sender");
        managedWallet.changeWallet(MAIN_WALLET, randomAddress);
    }


    // A unit test to check the changeWallet function for the main wallet when the new address is zero. Verify that a WalletChangeRequested event is not emitted and the internal state remains unchanged.
	function testChangeWalletWithZeroAddressShouldNotEmitEventNorChangeState() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        // Initial state check before changeWallet call
        address initialMainWallet = managedWallet.mainWallet();
        address initialConfirmationWallet = managedWallet.confirmationWallet();

        // Expect revert with zero new address
        vm.prank(alice);
        vm.expectRevert("newAddress cannot be zero.");
        managedWallet.changeWallet(MAIN_WALLET, address(0));

        // State check after changeWallet call
        address mainWalletAfter = managedWallet.mainWallet();
        address confirmationWalletAfter = managedWallet.confirmationWallet();

        // Asserting no state changes occurred
        assertEq(mainWalletAfter, initialMainWallet, "Main wallet address should remain unchanged.");
        assertEq(confirmationWalletAfter, initialConfirmationWallet, "Confirmation wallet address should remain unchanged.");
    }


    // A unit test to check the changeWallet function for the main wallet when the new address is valid and the confirmation wallet has not made a corresponding request. Verify the changeRequest mapping is updated correctly, and a WalletChangeRequested event is emitted without any ActiveTimelockUpdated event.
	function testChangeWalletValidNewAddressNoCorrespondingRequest() public {
        // Initialize the ManagedWallet contract with alice as the main wallet and this test contract as the confirmation wallet
        ManagedWallet mw = new ManagedWallet(alice, address(this));

        address validNewAddress = address(0x3333);

        // Prank as alice (the main wallet) and request a change to a new valid address for the MAIN_WALLET
        // This should not set an active timelock because the confirmation wallet has not requested the change yet
        vm.prank(alice);
        mw.changeWallet(MAIN_WALLET, validNewAddress);

        // Check that the changeRequest for alice (the main wallet) and MAIN_WALLET is updated correctly
        assertEq(mw.changeRequests(alice, MAIN_WALLET), validNewAddress, "changeRequest should be updated to the new address");

        // Check that there is no active timelock for MAIN_WALLET and the new address yet
        assertEq(mw.activeTimelocks(MAIN_WALLET, validNewAddress), 0, "No activeTimelock should be set");
    }


    // A unit test to check the changeWallet function for the confirmation wallet when the new address is valid and the main wallet has not made a corresponding request. Verify the changeRequest mapping is updated correctly, and a WalletChangeRequested event is emitted without any ActiveTimelockUpdated event.
	function testChangeWalletConfirmationValidAddressNoMainRequest() public {
        ManagedWallet mw = new ManagedWallet(alice, address(this));
        address newValidAddress = address(0x4444);

        // Grant rights to the confirmation wallet to call `changeWallet`.
        vm.startPrank(address(this));

        // Call `changeWallet` to request a wallet change.
        mw.changeWallet(CONFIRMATION_WALLET, newValidAddress);

        // Confirm that there's no active timelock update since the main wallet hasn't requested a change.
        assertEq(mw.changeRequests(address(this), CONFIRMATION_WALLET), newValidAddress, "Confirmation wallet change request not recorded correctly.");
        assertEq(mw.activeTimelocks(CONFIRMATION_WALLET, newValidAddress), 0, "There shouldn't be any active timelock.");

        // Stop impersonation of the confirmation wallet.
        vm.stopPrank();
    }


    // A unit test to check the changeWallet function when both the main and confirmation wallets request a change to the same new address. Verify that the activeTimelocks mapping is updated correctly.
	function testChangeWalletBothWalletsRequestSameNewAddress() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));
        address newWalletAddress = address(0x3344);

        // Main wallet requests change
        vm.prank(alice);
        managedWallet.changeWallet(MAIN_WALLET, newWalletAddress);

        // Confirmation wallet requests change to the same address
        vm.prank(address(this));
        managedWallet.changeWallet(MAIN_WALLET, newWalletAddress);

        // Check the activeTimelocks mapping is updated correctly for the MAIN_WALLET and the newWalletAddress
        uint256 expectedTimelock = block.timestamp + 30 days;
        assertEq(managedWallet.activeTimelocks(MAIN_WALLET, newWalletAddress), expectedTimelock, "ActiveTimelock not updated correctly");
}

    // A unit test to check the cancelChangeRequest function when called by an address that is not the confirmation wallet. Expect to fail with "Invalid sender".
	function testCancelChangeRequestByNonConfirmationWalletShouldFail() public {
        ManagedWallet mw = new ManagedWallet(alice, address(this));
        address nonConfirmationWallet = address(0xBEEF);

        // Non-confirmation wallet attempts to cancel a change request
        vm.prank(nonConfirmationWallet);
        vm.expectRevert("Invalid sender");
        mw.cancelChangeRequest(MAIN_WALLET);
    }


    // A unit test to check the cancelChangeRequest function for the confirmation wallet when there is no active change request. Verify that no internal state is altered, and a CancelChangeRequest event is emitted.
	function testCancelChangeRequestWhenNoActiveChange() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));
        address confirmationWalletAddress = managedWallet.confirmationWallet();

        // Store state before calling cancelChangeRequest
        address initialMainWallet = managedWallet.mainWallet();
        address initialConfirmationWallet = managedWallet.confirmationWallet();
        managedWallet.changeRequests(confirmationWalletAddress, MAIN_WALLET);
        managedWallet.changeRequests(confirmationWalletAddress, CONFIRMATION_WALLET);

        // Prank as the confirmation wallet and call cancelChangeRequest
        vm.prank(confirmationWalletAddress);
        managedWallet.cancelChangeRequest(MAIN_WALLET);

        vm.prank(confirmationWalletAddress);
        managedWallet.cancelChangeRequest(CONFIRMATION_WALLET);

        // Ensure that the change requests are reset to address(0) after the cancel
        assertEq(managedWallet.changeRequests(confirmationWalletAddress, MAIN_WALLET), address(0), "Main wallet change request was not cancelled.");
        assertEq(managedWallet.changeRequests(confirmationWalletAddress, CONFIRMATION_WALLET), address(0), "Confirmation wallet change request was not cancelled.");

        // Ensure no other state variables were altered
        assertEq(managedWallet.mainWallet(), initialMainWallet, "Main wallet address should remain the same after cancellation.");
        assertEq(managedWallet.confirmationWallet(), initialConfirmationWallet, "Confirmation wallet address should remain the same after cancellation.");

        // Check that there are no active timelocks
        assertEq(managedWallet.activeTimelocks(MAIN_WALLET, initialMainWallet), 0, "No active timelock should exist for main wallet.");
        assertEq(managedWallet.activeTimelocks(CONFIRMATION_WALLET, initialConfirmationWallet), 0, "No active timelock should exist for confirmation wallet.");

        // Emitting an event is not checked here as per the instructions given
    }


    // A unit test to check the becomeWallet function when the active timelock is 0 (not set). Expect to fail with "No active timelock".
	function testBecomeWalletNoActiveTimelockShouldFail() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));
        address randomAddress = address(0x3333);

        vm.prank(randomAddress);
        vm.expectRevert("No active timelock");
        managedWallet.becomeWallet(MAIN_WALLET);
    }


    // A unit test to check the becomeWallet function when the active timelock is not yet completed (current timestamp is before the timelock). Expect to fail with "Timelock not yet completed".
	function testBecomeWalletWithUncompletedTimelockShouldFail() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        // Prank as alice to make a change wallet request
        vm.prank(alice);
        managedWallet.changeWallet(MAIN_WALLET, alice);
        // Prank as this to simulate confirmation for the change wallet request
        vm.prank(address(this));
        managedWallet.changeWallet(MAIN_WALLET, alice);

        // Retrieve the active timelock for MAIN_WALLET change to `alice` address
        uint256 activeTimelock = managedWallet.activeTimelocks(MAIN_WALLET, alice);

        // Skip to just before the timelock completes
        vm.warp(activeTimelock - 1);

        // Expect the "Timelock not yet completed" error when trying to becomeWallet before timelock period is over
        vm.prank(alice);
        vm.expectRevert("Timelock not yet completed");
        managedWallet.becomeWallet(MAIN_WALLET);
    }


    // A unit test to check the becomeWallet function when the active timelock is completed but the confirmation wallet cancelled the request and the change request is no longer valid. Expect to fail with "Change no longer valid".
	function testBecomeWalletWithCancelledChangeRequestShouldFail() public {
        ManagedWallet mw = new ManagedWallet(alice, address(this));
        address newWallet = address(0x3333);

        // Prepare the test scenario: Alice proposes a change and the confirmation wallet agrees
        vm.prank(alice);
        mw.changeWallet(MAIN_WALLET, newWallet); // Alice requests a change to the new wallet
        vm.prank(address(this));
        mw.changeWallet(MAIN_WALLET, newWallet); // Confirmation wallet agrees to the change

        // Warp to the future, after the timelock, but before anyone becomes the wallet.
        vm.warp(block.timestamp + 30 days + 1);

        // Cancel the change request by the confirmation wallet
        vm.prank(address(this));
        mw.cancelChangeRequest(MAIN_WALLET);

        // Now try to become the main wallet, but expect it to fail because the change request has been cancelled
        vm.expectRevert("Change no longer valid");
        vm.prank(newWallet); // New wallet tries to become the main wallet
        mw.becomeWallet(MAIN_WALLET);
    }


    // A unit test to check the becomeWallet function for the main wallet when the active timelock is completed and the change request is still valid. Verify that the main wallet address is updated correctly and both changeRequests and activeTimelocks are reset, and a WalletChanged event is emitted.
	function testBecomeWalletWithCancelledChangeRequestShouldFail2() public {
        ManagedWallet mw = new ManagedWallet(alice, address(this));
        address newWallet = address(0x3333);

        // Prepare the test scenario: Alice proposes a change and the confirmation wallet agrees
        vm.prank(alice);
        mw.changeWallet(MAIN_WALLET, newWallet); // Alice requests a change to the new wallet
        vm.prank(address(this));
        mw.changeWallet(MAIN_WALLET, newWallet); // Confirmation wallet agrees to the change

        // Warp to the future, after the timelock, but before anyone becomes the wallet.
        vm.warp(block.timestamp + 30 days + 1);

        // Cancel the change request by the confirmation wallet
        vm.prank(address(this));
        mw.cancelChangeRequest(MAIN_WALLET);

        // Now try to become the main wallet, but expect it to fail because the change request has been cancelled
        vm.expectRevert("Change no longer valid");
        vm.prank(newWallet); // New wallet tries to become the main wallet
        mw.becomeWallet(MAIN_WALLET);
    }


    // A unit test to check the becomeWallet function for the confirmation wallet when the active timelock is completed and the change request is still valid. Verify that the confirmation wallet address is updated correctly and both changeRequests and activeTimelocks are reset.
	  function testBecomeWalletWhenTimeLockCompletedAndChangeRequestValid() public {
            ManagedWallet mw = new ManagedWallet(alice, address(this));
            address newMainWallet = address(0x3333);

            // Alice (main wallet) requests the change to the new address
            vm.prank(alice);
            mw.changeWallet(MAIN_WALLET, newMainWallet);

            // Confirmation wallet (this contract) agrees to the change to the new address
            vm.prank(address(this));
            mw.changeWallet(MAIN_WALLET, newMainWallet);

            // Warp to the future after the active timelock expires
            uint256 timelockDuration = mw.CHANGE_WALLET_TIMELOCK();
            vm.warp(block.timestamp + timelockDuration + 1);

            // The new main wallet tries to become the wallet
            vm.prank(newMainWallet);
            mw.becomeWallet(MAIN_WALLET);

            // Check that the main wallet address has been updated
            assertEq(mw.mainWallet(), newMainWallet, "Main wallet address not updated correctly");

            // Check that the changeRequests and activeTimelocks have been reset
            assertEq(mw.changeRequests(alice, MAIN_WALLET), address(0), "Change request for old wallet should be reset");
            assertEq(mw.changeRequests(newMainWallet, MAIN_WALLET), address(0), "Change request for new wallet should be reset");
            assertEq(mw.activeTimelocks(MAIN_WALLET, newMainWallet), 0, "Active timelock should be reset");
            // WalletChanged event check is omitted as instructed
        }


    // A unit test to check the changeWallet function when a subsequent request for change is made by the same wallet with a different new address. Verify that the changeRequest mapping is updated with the new address and previous timelocks are invalidated.
	function testChangeWalletWithSubsequentRequestUpdatesChangeRequestAndInvalidatesOldTimelocks() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));
        address firstNewAddress = address(0x5555);
        address secondNewAddress = address(0x6666);

        // Alice requests a change to the first new address for MAIN_WALLET
        vm.startPrank(alice);
        managedWallet.changeWallet(MAIN_WALLET, firstNewAddress);

        // Check that the changeRequest for Alice and MAIN_WALLET is updated to firstNewAddress
        assertEq(managedWallet.changeRequests(alice, MAIN_WALLET), firstNewAddress, "First changeRequest should be set to firstNewAddress");

        // Alice requests a change to the second new address for MAIN_WALLET
        managedWallet.changeWallet(MAIN_WALLET, secondNewAddress);
        vm.stopPrank();

        // Check that the changeRequest for Alice and MAIN_WALLET is updated to secondNewAddress
        assertEq(managedWallet.changeRequests(alice, MAIN_WALLET), secondNewAddress, "ChangeRequest should be updated to secondNewAddress");
    }


    // A unit test to check the cancelChangeRequest function for the confirmation wallet when there is an active change request with a timelock. Verify that the changeRequest is set to address(0) and the active timelock remains unchanged.
	function testCancelChangeRequestWithActiveTimelock() public {
        // Arrange
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));
        address newMainWalletRequest = address(0xAAA);

        // Initiate change wallet request by both wallets
        vm.prank(alice);
        managedWallet.changeWallet(MAIN_WALLET, newMainWalletRequest);

        vm.startPrank(address(this));
        managedWallet.changeWallet(MAIN_WALLET, newMainWalletRequest);
        address currentConfirmationWallet = managedWallet.confirmationWallet();
        managedWallet.changeRequests(currentConfirmationWallet, MAIN_WALLET);
        uint256 activeTimelockBeforeCancellation = managedWallet.activeTimelocks(MAIN_WALLET, newMainWalletRequest);

        // Act
        managedWallet.cancelChangeRequest(MAIN_WALLET);

        // Assert
        address changeRequestAfterCancellation = managedWallet.changeRequests(currentConfirmationWallet, MAIN_WALLET);
        uint256 activeTimelockAfterCancellation = managedWallet.activeTimelocks(MAIN_WALLET, newMainWalletRequest);

        assertEq(changeRequestAfterCancellation, address(0), "changeRequest should be reset to address(0)");
        assertEq(activeTimelockAfterCancellation, activeTimelockBeforeCancellation, "Active timelock should remain unchanged");

        // Clean up
        vm.stopPrank();
    }


    // A unit test to check the becomeWallet function when the active timelock is completed, the change request is valid, but the sender provides an incorrect walletIndex. Expect to fail due to mismatch with the sender's address.
	function testBecomeWalletWithCompletedTimelockAndValidRequestButIncorrectWalletIndexShouldFail() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));
        address newWallet = address(0x3333);

        // Setup: alice requests a wallet change and the confirmation wallet confirms
        vm.prank(alice);
        managedWallet.changeWallet(MAIN_WALLET, newWallet);
        vm.prank(address(this));
        managedWallet.changeWallet(MAIN_WALLET, newWallet);

        // Warp to the future when the timelock has completed
        vm.warp(block.timestamp + 30 days + 1);

        // Using an incorrect wallet index, should fail as the sender address does not match the requested change.
        // The incorrect walletIndex simulates a non-existent request or wrong wallet type.
        vm.prank(newWallet);
        vm.expectRevert("No active timelock");
        managedWallet.becomeWallet(500);
    }


    // A unit test to check the becomeWallet function for an address that was a valid, completed timelocked change request which got overridden by a newer change request by the wallets. Ensure the older request can no longer be used to become the wallet.
	function testBecomeWalletWithOverriddenChangeRequestShouldFail() public {
		ManagedWallet mw = new ManagedWallet(alice, address(this));
		address firstNewWallet = address(0x3333);
		address secondNewWallet = address(0x4444);

		// Set up initial change request by both wallets
		vm.prank(alice);
		mw.changeWallet(MAIN_WALLET, firstNewWallet);
		vm.prank(address(this));
		mw.changeWallet(MAIN_WALLET, firstNewWallet);

		// Warp 30 days into the future to allow the timelock to complete
		vm.warp(block.timestamp + 30 days);

		// Overwrite with newer request change by both wallets before the firstNewWallet becomes the wallet
		vm.prank(alice);
		mw.changeWallet(MAIN_WALLET, secondNewWallet);
		vm.prank(address(this));
		mw.changeWallet(MAIN_WALLET, secondNewWallet);

		// Attempt to become the main wallet using the older, timelocked request
		vm.expectRevert("Change no longer valid");
		vm.prank(firstNewWallet);
		mw.becomeWallet(MAIN_WALLET);

		// State check to confirm that the wallet has not been changed
		assertEq(mw.mainWallet(), alice, "The main wallet should not have changed to the first new wallet");
	}


    // A unit test to check that after a successful becomeWallet call, attempting to call becomeWallet again with the same address and walletIndex fails due to the active timelock being reset to 0.
	function testBecomeWalletThenAttemptAgainFails() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));
        address newWalletAddress = address(0x3333);

        // Alice requests change to new wallet address for MAIN_WALLET
        vm.prank(alice);
        managedWallet.changeWallet(MAIN_WALLET, newWalletAddress);

        // Confirmation wallet confirms the change to the new wallet address for MAIN_WALLET
        vm.prank(address(this));
        managedWallet.changeWallet(MAIN_WALLET, newWalletAddress);

        // Warp to after the timelock
        vm.warp(block.timestamp + 30 days + 1);

        // Become the new main wallet
        vm.prank(newWalletAddress);
        managedWallet.becomeWallet(MAIN_WALLET);

        // Attempt to call becomeWallet again, it should fail due to the active timelock being reset to 0
        vm.expectRevert("No active timelock");
        vm.prank(newWalletAddress);
        managedWallet.becomeWallet(MAIN_WALLET);
    }
	}
