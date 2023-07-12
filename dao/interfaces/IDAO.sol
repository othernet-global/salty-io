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
	}