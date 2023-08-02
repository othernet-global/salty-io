// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;


interface IArbitrageProfits
	{
	function clearProfitsForPools( bytes32[] memory poolIDs ) external;

	// Views
	function profitsForPools( bytes32[] memory poolIDs ) external view returns (uint256[] memory profits);
	}
