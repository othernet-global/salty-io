// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;


interface IAirdrop
	{
	function whitelistWallet( bytes memory signature ) external;
	function allowClaiming() external;
	function claimAirdrop() external;

	// Views
	function saltAmountForEachUser() external returns (uint256);
	function claimingAllowed() external returns (bool);
	function claimed(address wallet) external returns (bool);

	function whitelisted(address wallet) external returns (bool);
	function numberWhitelisted() external returns (uint256);
	function whitelistedWallets() external view returns (address[] calldata);
	}
