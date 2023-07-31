// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;


interface IAccessManager
	{
	function excludedCountriesUpdated() external;
	function grantAccess() external;

	// Views
	function walletHasAccess(address wallet) external view returns (bool);
	}
