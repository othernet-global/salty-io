// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../rewards/interfaces/IRewardsConfig.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "./interfaces/IDAOConfig.sol";


abstract contract Parameters
    {
	enum ParameterTypes {

		// PoolsConfig
		maximumWhitelistedPools,

		// StakingConfig
		minUnstakeWeeks,
		maxUnstakeWeeks,
		minUnstakePercent,
		modificationCooldown,

		// RewardsConfig
    	rewardsEmitterDailyPercentTimes1000,
		emissionsWeeklyPercentTimes1000,
		stakingRewardsPercent,

		// DAOConfig
		bootstrappingRewards,
		percentRewardsBurned,
		baseBallotQuorumPercentTimes1000,
		ballotDuration,
		requiredProposalPercentStakeTimes1000,
		percentRewardsForReserve,
		upkeepRewardPercent,
		ballotMaximumDuration
		}


	// If the parameter has an invalid parameterType then the call is a no-op
	function _executeParameterChange( ParameterTypes parameterType, bool increase, IPoolsConfig poolsConfig, IStakingConfig stakingConfig, IRewardsConfig rewardsConfig, IDAOConfig daoConfig ) internal
		{
		// PoolsConfig
		if ( parameterType == ParameterTypes.maximumWhitelistedPools )
			poolsConfig.changeMaximumWhitelistedPools( increase );

		// StakingConfig
		else if ( parameterType == ParameterTypes.minUnstakeWeeks )
			stakingConfig.changeMinUnstakeWeeks(increase);
		else if ( parameterType == ParameterTypes.maxUnstakeWeeks )
			stakingConfig.changeMaxUnstakeWeeks(increase);
		else if ( parameterType == ParameterTypes.minUnstakePercent )
			stakingConfig.changeMinUnstakePercent(increase);
		else if ( parameterType == ParameterTypes.modificationCooldown )
			stakingConfig.changeModificationCooldown(increase);

		// RewardsConfig
		else if ( parameterType == ParameterTypes.rewardsEmitterDailyPercentTimes1000 )
			rewardsConfig.changeRewardsEmitterDailyPercent(increase);
		else if ( parameterType == ParameterTypes.emissionsWeeklyPercentTimes1000 )
			rewardsConfig.changeEmissionsWeeklyPercent(increase);
		else if ( parameterType == ParameterTypes.stakingRewardsPercent )
			rewardsConfig.changeStakingRewardsPercent(increase);

		// DAOConfig
		else if ( parameterType == ParameterTypes.bootstrappingRewards )
			daoConfig.changeBootstrappingRewards(increase);
		else if ( parameterType == ParameterTypes.percentRewardsBurned )
			daoConfig.changePercentRewardsBurned(increase);
		else if ( parameterType == ParameterTypes.baseBallotQuorumPercentTimes1000 )
			daoConfig.changeBaseBallotQuorumPercent(increase);
		else if ( parameterType == ParameterTypes.ballotDuration )
			daoConfig.changeBallotDuration(increase);
		else if ( parameterType == ParameterTypes.requiredProposalPercentStakeTimes1000 )
			daoConfig.changeRequiredProposalPercentStake(increase);
		else if ( parameterType == ParameterTypes.percentRewardsForReserve )
			daoConfig.changePercentRewardsForReserve(increase);
		else if ( parameterType == ParameterTypes.upkeepRewardPercent )
			daoConfig.changeUpkeepRewardPercent(increase);
		else if ( parameterType == ParameterTypes.ballotMaximumDuration )
			daoConfig.changeBallotMaximumDuration(increase);
		}
	}