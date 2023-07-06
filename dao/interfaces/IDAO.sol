// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./IProposals.sol";
import "../../rewards/interfaces/IRewardsConfig.sol";
import "../../rewards/interfaces/IRewardsEmitter.sol";
import "../../stable/interfaces/IStableConfig.sol";
import "../../staking/interfaces/ILiquidity.sol";


interface IDAO is IProposals
	{
	function finalizeBallot( uint256 ballotID ) external;
	function sufficientBootstrappingRewardsExistForWhitelisting() external view returns (bool);
	function countryIsExcluded( string calldata country ) external view returns (bool);

	function rewardsConfig() external view returns (IRewardsConfig);
	function stableConfig() external view returns (IStableConfig);
	function liquidity() external view returns (ILiquidity);
	function liquidityRewardsEmitter() external view returns (IRewardsEmitter);
	}