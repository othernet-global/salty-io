// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

interface IDAO
	{
	function finalizeBallot( uint256 ballotID ) external;
	function sufficientBootstrappingRewardsExistForWhitelisting() external view returns (bool);
	function countryIsExcluded( string calldata country ) external view returns (bool);
	function performUpkeep() external;

	// Views
	function websiteURL() external returns (string memory);
	}