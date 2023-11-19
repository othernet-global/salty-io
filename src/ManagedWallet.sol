// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./interfaces/IManagedWallet.sol";


// A smart contract which provides two wallet addresses (a main and confirmation wallet) which can be changed using the following mechanism:
// 1. Main wallet can propose a new main wallet and confirmation wallet.
// 2. Confirmation wallet confirms or rejects.
// 3. There is a timelock of 30 days before the proposed mainWallet can confirm the change.

contract ManagedWallet is IManagedWallet
    {
    event WalletProposal(address proposedMainWallet, address proposedConfirmationWallet);
    event WalletChange(address mainWallet, address confirmationWallet);

    uint256 constant public TIMELOCK_DURATION = 30 days;

    // The active main and confirmation wallets
    address public mainWallet;
    address public confirmationWallet;

	// Proposed wallets
    address public proposedMainWallet;
    address public proposedConfirmationWallet;

	// Active timelock
    uint256 public activeTimelock;


	constructor( address _mainWallet, address _confirmationWallet)
		{
		mainWallet = _mainWallet;
		confirmationWallet = _confirmationWallet;

		// Write a value so subsequent writes take less gas
		activeTimelock = type(uint256).max;
        }


	// Make a request to change the main and confirmation wallets.
	function proposeWallets( address _proposedMainWallet, address _proposedConfirmationWallet ) external
		{
		require( msg.sender == mainWallet, "Only the current mainWallet can propose changes" );
		require( _proposedMainWallet != address(0), "_proposedMainWallet cannot be the zero address" );
		require( _proposedConfirmationWallet != address(0), "_proposedConfirmationWallet cannot be the zero address" );

		// Make sure we're not overwriting a previous proposal (as only the confirmationWallet can reject proposals)
		require( proposedMainWallet == address(0), "Cannot overwrite non-zero proposed mainWallet." );

		proposedMainWallet = _proposedMainWallet;
		proposedConfirmationWallet = _proposedConfirmationWallet;

		emit WalletProposal(proposedMainWallet, proposedConfirmationWallet);
		}


	// The confirmation wallet confirms or rejects wallet proposals by sending a specific amount of ETH to this contract
    receive() external payable
    	{
    	require( msg.sender == confirmationWallet, "Invalid sender" );

		// Confirm if .05 or more ether is sent and otherwise reject.
		// Done this way in case custodial wallets are used as the confirmationWallet - which sometimes won't allow for smart contract calls.
    	if ( msg.value >= .05 ether )
    		activeTimelock = block.timestamp + TIMELOCK_DURATION; // establish the timelock
    	else
			activeTimelock = type(uint256).max; // effectively never
        }


	// Confirm the wallet proposals - assuming that the active timelock has already expired.
	function changeWallets() external
		{
		// proposedMainWallet calls the function - to make sure it is a valid address.
		require( msg.sender == proposedMainWallet, "Invalid sender" );
		require( block.timestamp >= activeTimelock, "Timelock not yet completed" );

		// Set the wallets
		mainWallet = proposedMainWallet;
		confirmationWallet = proposedConfirmationWallet;

		emit WalletChange(mainWallet, confirmationWallet);

		// Reset
		activeTimelock = type(uint256).max;
		proposedMainWallet = address(0);
		proposedConfirmationWallet = address(0);
		}
	}
