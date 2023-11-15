// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "./interfaces/IManagedWallet.sol";


// A smart contract which provides two wallet addresses (a main and confirmation wallet) which can each be changed using the following mechanism:
// 1. Both current wallets must approve any change.
// 2. There is a timelock of 30 days before a proposed wallet can confirm the change.
// 3. The confirmation wallet can cancel any pending change before it is finalized - by calling changeWallet with another address.

contract ManagedWallet is IManagedWallet
    {
    event WalletChangeRequested(uint256 indexed walletIndex, address requestedBy, address newWalletAddress);
    event ActiveTimelockUpdated(uint256 indexed walletIndex, address newWalletAddress, uint256 timestamp);
    event CancelChangeRequest(uint256 indexed walletIndex);
    event WalletChanged(uint256 indexed walletIndex, address newWalletAddress);

    uint256 constant public MAIN_WALLET = 0;
    uint256 constant public CONFIRMATION_WALLET = 1;

    uint256 constant public CHANGE_WALLET_TIMELOCK = 30 days;

    // The addresses of the main and confirmation wallets;
    address[] public wallets;

	// Change requests [caller][walletIndex]
	mapping(address=>mapping(uint256=>address)) private _changeRequests;

	// Active timelocks [walletIndex][newAddress]
	mapping(uint256=>mapping(address=>uint256)) private _activeTimelocks;


	constructor( address _mainWallet, address _confirmationWallet)
		{
		wallets = new address[](2);

		wallets[MAIN_WALLET] = _mainWallet;
		wallets[CONFIRMATION_WALLET] = _confirmationWallet;
        }


	// Make a request to change the main or confirmation wallet.
	// If the change has been confirmed by both the main and confirmation wallets, then an activeTimelock for the change is created.
	function changeWallet( uint256 walletIndex, address newAddress ) public
		{
		require( (msg.sender == mainWallet()) || ( msg.sender == confirmationWallet()), "Invalid sender" );
		require( newAddress != address(0), "newAddress cannot be zero." );

		// Record that the sender wants the specified wallet to be the new address
		_changeRequests[msg.sender][walletIndex] = newAddress;

		emit WalletChangeRequested(walletIndex, msg.sender, newAddress);

		// If both the main and confirmation wallets have the same changeRequest then update activeTimelocks to allow final confirmation in 30 days.
		if ( _changeRequests[ mainWallet() ][walletIndex] == newAddress )
		if ( _changeRequests[ confirmationWallet() ][walletIndex] == newAddress )
			{
			_activeTimelocks[walletIndex][newAddress] = block.timestamp + CHANGE_WALLET_TIMELOCK;

			emit ActiveTimelockUpdated(walletIndex, newAddress, _activeTimelocks[walletIndex][newAddress]);
			}
		}


	// Allow the confirmation wallet to cancel a change - as it will cause a require in the becomeWallet function to fail.
	function cancelChangeRequest(uint256 walletIndex) public
		{
		require( msg.sender == confirmationWallet(), "Invalid sender" );

		_changeRequests[msg.sender][walletIndex] = address(0);

		emit CancelChangeRequest(walletIndex);
		}


	// Become the main or confirmation wallet - assuming that the active timelock from dual approval is already in place.
	function becomeWallet( uint256 walletIndex ) public
		{
		require( _activeTimelocks[walletIndex][msg.sender] != 0, "No active timelock" );
		require( block.timestamp >= _activeTimelocks[walletIndex][msg.sender], "Timelock not yet completed" );

		// Make sure the confirmation wallet still considers the request valid - as a mechanism to cancel the change request.
		require( _changeRequests[ confirmationWallet() ][walletIndex] == msg.sender, "Change no longer valid" );

		// Reset
		_activeTimelocks[walletIndex][msg.sender] = 0;
		_changeRequests[ mainWallet() ][walletIndex] = address(0);
		_changeRequests[ confirmationWallet() ][walletIndex] = address(0);

		// Make the change
		wallets[walletIndex] = msg.sender;

		emit WalletChanged(walletIndex, msg.sender);
		}


    // === VIEWS ===
    function mainWallet() public view returns (address wallet)
    	{
    	return wallets[MAIN_WALLET];
    	}


    function confirmationWallet() public view returns (address wallet)
    	{
    	return wallets[CONFIRMATION_WALLET];
    	}


   	function changeRequests( address caller, uint256 walletIndex ) external view returns (address newAddress)
   		{
   		return _changeRequests[caller][walletIndex];
   		}


   	function activeTimelocks( uint256 walletIndex, address newAddress ) external view returns (uint256 timelock)
   		{
   		return _activeTimelocks[walletIndex][newAddress];
   		}
	}
