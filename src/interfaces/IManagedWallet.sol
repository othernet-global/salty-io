// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IManagedWallet
	{
	function proposeWallets( address _proposedMainWallet, address _proposedConfirmationWallet ) external;
	function changeWallets() external;

	// Views
	function mainWallet() external view returns (address wallet);
	function confirmationWallet() external view returns (address wallet);
	function proposedMainWallet() external view returns (address wallet);
	function proposedConfirmationWallet() external view returns (address wallet);
    function activeTimelock() external view returns (uint256);
	}
