// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;


interface IPoolStats
	{
	// These are the indicies (in terms of a poolIDs location in the current whitelistedPoolIDs array) of pools involved in an arbitrage path
	struct ArbitrageIndicies
		{
		uint64 index1;
		uint64 index2;
		uint64 index3;
		}

	function clearProfitsForPools() external;
	function updateArbitrageIndicies() external;

	// Views
	function profitsForWhitelistedPools() external view returns (uint256[] memory _calculatedProfits);
	function arbitrageIndicies(bytes32 poolID) external view returns (ArbitrageIndicies memory);
	}

