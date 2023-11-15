// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IAccessManager
	{
	function excludedCountriesUpdated() external;
	function grantAccess(bytes calldata signature) external;

	// Views
	function geoVersion() external view returns (uint256);
	function walletHasAccess(address wallet) external view returns (bool);
	}
