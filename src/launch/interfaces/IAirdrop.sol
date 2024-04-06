// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IAirdrop
	{
	function authorizeWallet( address wallet, uint256 saltAmount ) external;
	function allowClaiming() external;
	function claim() external;

	// Views
	function claimedByUser( address wallet) external view returns (uint256);
	function claimingAllowed() external view returns (bool);
	function claimingStartTimestamp() external view returns (uint256);
	function claimableAmount(address wallet) external view returns (uint256);
    function airdropForUser( address wallet ) external view returns (uint256);
	}
