// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IManagedWallet
	{
	function changeWallet( uint256 walletIndex, address newAddress ) external;
	function becomeWallet( uint256 walletIndex ) external;

	// Views
	function mainWallet() external returns (address wallet);
	function confirmationWallet() external returns (address wallet);
   	function changeRequests( address caller, uint256 walletIndex ) external view returns (address newAddress);
   	function activeTimelocks( uint256 walletIndex, address newAddress ) external view returns (uint256 timelock);
	}
