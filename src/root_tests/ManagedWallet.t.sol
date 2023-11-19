// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../dev/Deployment.sol";


contract TestManagedWallet is Deployment
	{
    address public constant alice = address(0x1111);

    uint256 constant public TIMELOCK_DURATION = 30 days;


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


    // A unit test to check the proposeWallets function when called by the current mainWallet with valid non-zero addresses. Ensure that the proposedMainWallet and proposedConfirmationWallet state variables are set to these addresses.
	function testProposeWalletsByMainWalletWithValidAddresses() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(0x2222));
        address proposedMainWallet = address(0x3333);
        address proposedConfirmationWallet = address(0x4444);

        vm.startPrank(alice);
        managedWallet.proposeWallets(proposedMainWallet, proposedConfirmationWallet);
        vm.stopPrank();

        assertEq(managedWallet.proposedMainWallet(), proposedMainWallet, "proposedMainWallet not set correctly");
        assertEq(managedWallet.proposedConfirmationWallet(), proposedConfirmationWallet, "proposedConfirmationWallet not set correctly");
    }


    // A unit test to check the proposeWallets function when called by an address other than the current mainWallet. Expect the transaction to revert with the "Only the current mainWallet can propose changes" error.
	function testProposeWalletsRevertNotMainWallet() public {
        address notMainWallet = address(0x1234);
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        vm.prank(notMainWallet);
        vm.expectRevert("Only the current mainWallet can propose changes");
        managedWallet.proposeWallets(address(0xdead), address(0xbeef));
    }


    // A unit test to check the proposeWallets function when _proposedMainWallet is the zero address. Expect the transaction to revert with the "_proposedMainWallet cannot be the zero address" error.
	function testProposeWalletsRevertsWhenZeroAddressIsProposed() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        vm.expectRevert("_proposedMainWallet cannot be the zero address");
    	vm.prank(alice);
    	managedWallet.proposeWallets(address(0), address(this));
    }


    // A unit test to check the proposeWallets function when _proposedConfirmationWallet is the zero address. Expect the transaction to revert with the "_proposedConfirmationWallet cannot be the zero address" error.
	function testProposeWalletsRevertsWhenZeroConfirmationAddressIsProposed() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        vm.expectRevert("_proposedConfirmationWallet cannot be the zero address");
    	vm.prank(alice);
    	managedWallet.proposeWallets(address(this), address(0));
    }


    // A unit test to check the proposeWallets function when there is already a non-zero proposedMainWallet. Expect the transaction to revert with the "Cannot overwrite non-zero proposed mainWallet." error.
	function testProposeWalletsRevertsIfProposedMainWalletIsNonZero() public {
        address nonZeroProposedMainWallet = address(0x5555);
        address nonZeroProposedConfirmationWallet = address(0x6666);
        ManagedWallet managedWallet = new ManagedWallet(alice, address(0x2222));

        // Simulate that the mainWallet has already proposed wallets
        vm.prank(alice);
        managedWallet.proposeWallets(nonZeroProposedMainWallet, nonZeroProposedConfirmationWallet);

        // Try proposing new wallets again, which should not be allowed
        address newProposedMainWallet = address(0x7777);
        address newProposedConfirmationWallet = address(0x8888);
        vm.prank(alice);
        vm.expectRevert("Cannot overwrite non-zero proposed mainWallet.");
        managedWallet.proposeWallets(newProposedMainWallet, newProposedConfirmationWallet);
    }


    // A unit test to check the receive function when sent by the current confirmationWallet with more than .05 ether. Ensure that the activeTimelock is set to the current block timestamp plus TIMELOCK_DURATION.
	function testReceiveFunctionWithCurrentConfirmationWalletAndSufficientEther() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        // Assume confirmationWallet is the address running this test, therefore we use `address(this)`
        uint256 sentValue = 0.06 ether;
        uint256 expectedTimelock = block.timestamp + 30 days;

        // Send more than .05 ether to trigger the activeTimelock update
        vm.prank(address(this));
        vm.deal(address(this), sentValue);

        // Call the receive function by sending ether
        (bool success,) = address(managedWallet).call{value: sentValue}("");

        assertTrue(success, "Receive function failed");
        assertEq(managedWallet.activeTimelock(), expectedTimelock, "activeTimelock not set correctly");
    }


    // A unit test to check the receive function when sent by the current confirmationWallet with exactly .05 ether. Ensure that the activeTimelock is set to the current block timestamp plus TIMELOCK_DURATION.
	function testReceiveFunctionWithExactly05EtherFromConfirmationWallet() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        // Assume confirmationWallet is the address running this test, therefore we use `address(this)`
        uint256 sentValue = 0.05 ether;
        uint256 expectedTimelock = block.timestamp + 30 days;

        // Send .05 or more ether to trigger the activeTimelock update
        vm.prank(address(this));
        vm.deal(address(this), sentValue);

        // Call the receive function by sending ether
        (bool success,) = address(managedWallet).call{value: sentValue}("");

        assertTrue(success, "Receive function failed");
        assertEq(managedWallet.activeTimelock(), expectedTimelock, "activeTimelock not set correctly");
    }


    // A unit test to check the receive function when sent by the current confirmationWallet with less than .05 ether. Ensure that the activeTimelock is set to type(uint256).max.
	function testReceiveFunctionFromConfirmationWalletWithLessThanMinimumEther() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        // amount less than required (.05 ether) to be sent by the confirmationWallet
        uint256 amountToSend = 0.04 ether;

        // Prank the confirmationWallet
        vm.prank(address(this));

        // Fund confirmationWallet with the specified amount
        vm.deal(address(this), amountToSend);

        // Expect that when a transaction is received with less than .05 ether, it will revert
        vm.expectRevert("Invalid sender");
        (bool success, ) = address(managedWallet).call{value: amountToSend}("");

        // Check that the activeTimelock remains unchanged
        uint256 expectedTimelock = type(uint256).max;
        assertEq(managedWallet.activeTimelock(), expectedTimelock, "activeTimelock should remain unchanged");
        assertTrue(!success, "Transaction should not be successful");
    }


    // A unit test to check the receive function when sent by an address other than the current confirmationWallet. Expect the transaction to revert with the "Invalid sender" error.
	function testReceiveFunctionRevertsInvalidSender() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        address invalidSender = address(0x5555);
        vm.prank(invalidSender);
        vm.expectRevert("Invalid sender");
        (bool success,) = address(managedWallet).call{value: 1 ether}("");
        assertTrue(!success, "Transaction should not be successful");
    }


    // A unit test to check the changeWallets function when called by the proposedMainWallet after the activeTimelock has expired. Ensure that the mainWallet and confirmationWallet state variables are set to the previously proposed addresses. Also ensure that proposedMainWallet and proposedConfirmationWallet are reset to address(0), and activeTimelock is reset to type(uint256).max.
	function testChangeWalletsByProposedMainWalletAfterActiveTimelock() public {
        // Set up the initial state with main and confirmation wallets
        address initialMainWallet = alice;
        address initialConfirmationWallet = address(0x2222);
        ManagedWallet managedWallet = new ManagedWallet(initialMainWallet, initialConfirmationWallet);

        // Set up the proposed main and confirmation wallets
        address newMainWallet = address(0x3333);
        address newConfirmationWallet = address(0x4444);

        // Prank as the initial main wallet to propose the new wallets
        vm.startPrank(initialMainWallet);
        managedWallet.proposeWallets(newMainWallet, newConfirmationWallet);
        vm.stopPrank();

        // Prank as the current confirmation wallet and send ether to confirm the proposal
        uint256 sentValue = 0.06 ether;
        vm.prank(initialConfirmationWallet);
        vm.deal(initialConfirmationWallet, sentValue);
        (bool success,) = address(managedWallet).call{value: sentValue}("");
        assertTrue(success, "Confirmation of wallet proposal failed");

        // Warp the blockchain time to the future beyond the active timelock period
        uint256 currentTime = block.timestamp;
        vm.warp(currentTime + TIMELOCK_DURATION);

        // Expect revert for other than the proposedMainWallet calling the function before the timelock duration has completed
        vm.expectRevert("Invalid sender");
        managedWallet.changeWallets();

        // Prank as the new proposed main wallet which should now be allowed to call changeWallets
        vm.prank(newMainWallet);
        managedWallet.changeWallets();

        // Check that the mainWallet and confirmationWallet state variables are updated
        assertEq(managedWallet.mainWallet(), newMainWallet, "mainWallet was not updated correctly");
        assertEq(managedWallet.confirmationWallet(), newConfirmationWallet, "confirmationWallet was not updated correctly");

        // Check that the proposed wallets and activeTimelock have been reset
        assertEq(managedWallet.proposedMainWallet(), address(0), "proposedMainWallet was not reset");
        assertEq(managedWallet.proposedConfirmationWallet(), address(0), "proposedConfirmationWallet was not reset");
        assertEq(managedWallet.activeTimelock(), type(uint256).max, "activeTimelock was not reset to max uint256");
    }


    // A unit test to check the changeWallets function when called by an address other than the proposedMainWallet. Expect the transaction to revert with the "Invalid sender" error.
	function testChangeWalletsShouldRevertForNonProposedMainWallet() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(0x2222));

        // Expect the changeWallets function to revert when not called by the proposedMainWallet
        address invalidCaller = address(0x5555);
        vm.prank(invalidCaller);
        vm.expectRevert("Invalid sender");
        managedWallet.changeWallets();
    }


    // A unit test to check the changeWallets function when called by the proposedMainWallet before the activeTimelock has expired. Expect the transaction to revert with the "Timelock not yet completed" error.
	function testChangeWalletsRevertsWhenTimelockNotExpired() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));
        address proposedMainWallet = address(0x3333);
        address proposedConfirmationWallet = address(0x4444);

        // Simulate the proposal of new wallets
        vm.prank(alice);
        managedWallet.proposeWallets(proposedMainWallet, proposedConfirmationWallet);

        // Send more than .05 ether to confirmation wallet to establish the active timelock
        vm.prank(address(this));
       (bool success,) =  address(managedWallet).call{value: 0.06 ether}("");
		assertTrue(success);

        // Move forward in time but not past the timelock
        uint256 timeBeforeTimelockExpires = managedWallet.activeTimelock() - 1 hours;
        vm.warp(timeBeforeTimelockExpires);

        // Attempt to change wallets prior to timelock expiry
        vm.startPrank(proposedMainWallet);
        vm.expectRevert("Timelock not yet completed");
        managedWallet.changeWallets();
        vm.stopPrank();
    }


    // A unit test to check the changeWallets function when no proposed wallets are set (proposedMainWallet and proposedConfirmationWallet are zero addresses). Expect the transaction to revert with the "Invalid sender" error or because the timelock check would fail due to the default value of activeTimelock.
	 function testChangeWalletsWithNoProposedWallets() public {
            ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

            // Check for revert due to "Invalid sender" when no proposed addresses are setup
            vm.expectRevert("Invalid sender");
            managedWallet.changeWallets();
        }


    // A unit test to check the functionality when the proposedMainWallet or proposedConfirmationWallet is the same as the current mainWallet or confirmationWallet respectively. Ensure that the function can still complete successfully if all other conditions are met.
    function testProposeWalletsWithSameCurrentAddresses() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, alice);

        address newMainWalletAddress = alice; // Same as the current mainWallet
        address newConfirmationWalletAddress = alice; // Same as the current confirmationWallet

        // Ensure that no revert is expected even when the proposed wallets are the same as the current ones.
        vm.prank(alice);
        managedWallet.proposeWallets(newMainWalletAddress, newConfirmationWalletAddress);

        assertEq(managedWallet.proposedMainWallet(), newMainWalletAddress, "Proposed main wallet should be set correctly even if it's the same as current mainWallet");
        assertEq(managedWallet.proposedConfirmationWallet(), newConfirmationWalletAddress, "Proposed confirmation wallet should be set correctly even if it's the same as current confirmationWallet");
    }


    // A unit test to ensure that when the mainWallet is changed, subsequent calls to proposeWallets by the old mainWallet address fail.
    function testChangeMainWalletAndFailSubsequentProposeWalletsByOldMainWallet() public {
            address newMainWallet = address(0x3333);
            ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

            // Propose new main wallet
            vm.prank(alice);
            managedWallet.proposeWallets(newMainWallet, address(this));

            // Confirm the proposal as the confirmation wallet
            vm.prank(address(this));
        	vm.deal(address(this), 0.06 ether);
            (bool success,) = address(managedWallet).call{value: 0.06 ether}("");
            assertTrue(success, "Confirmation of proposal failed");

            // Forward time past the active timelock
            vm.warp(block.timestamp + TIMELOCK_DURATION);

            // Change the wallets using the new proposed main wallet
            vm.startPrank(newMainWallet);
            managedWallet.changeWallets();
            vm.stopPrank();

            // Ensure that the main wallet has been changed
            assertEq(managedWallet.mainWallet(), newMainWallet, "mainWallet should be updated to newMainWallet");

            // Attempt to propose wallets by the old main wallet (alice)
            address attemptNewProposedMainWallet = address(0x5555);
            address attemptNewProposedConfirmationWallet = address(0x6666);

            // Expect revert because alice is not the main wallet anymore
            vm.startPrank(alice);
            vm.expectRevert("Only the current mainWallet can propose changes");
            managedWallet.proposeWallets(attemptNewProposedMainWallet, attemptNewProposedConfirmationWallet);
            vm.stopPrank();
    }


    // A unit test to verify that upon proposing new wallets, the activeTimelock remains unchanged until the confirmationWallet sends the necessary ether.
    function testActiveTimelockUnchangedUntilConfirmation() public {
        ManagedWallet managedWallet = new ManagedWallet(alice, address(this));

        // Propose new wallets
        address newMainWallet = address(0x3333);
        address newConfirmationWallet = address(0x4444);
        vm.prank(alice);
        managedWallet.proposeWallets(newMainWallet, newConfirmationWallet);

        // Check that activeTimelock is not yet set (remains the max uint256 value)
        uint256 activeTimelockBefore = managedWallet.activeTimelock();
        assertEq(activeTimelockBefore, type(uint256).max, "initial activeTimelock should be max uint256");

        // Confirmation wallet sends necessary ether to confirm the proposal
        uint256 amountToSend = 1 ether;
        vm.prank(address(this));
        vm.deal(address(this), amountToSend);
		(bool success,) = address(managedWallet).call{value: amountToSend}("");
		assertTrue(success, "Confirmation of proposal failed");

        // Ensure activeTimelock is now updated to current timestamp + TIMELOCK_DURATION
        uint256 expectedTimelock = block.timestamp + TIMELOCK_DURATION;
        uint256 activeTimelockAfterValidConfirmation = managedWallet.activeTimelock();
        assertEq(activeTimelockAfterValidConfirmation, expectedTimelock, "activeTimelock not updated after confirmation");
    }
	}
