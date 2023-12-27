// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IAirdrop
	{
	function authorizeWallet( address wallet ) external;
	function allowClaiming() external;
	function claimAirdrop() external;

	// Views
	function saltAmountForEachUser() external view returns (uint256);
	function claimingAllowed() external view returns (bool);
	function claimed(address wallet) external view returns (bool);

	function isAuthorized(address wallet) external view returns (bool);
	function numberAuthorized() external view returns (uint256);
	}
