// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./interfaces/IDAOConfig.sol";
import "../rewards/interfaces/IRewardsConfig.sol";
import "../stable/interfaces/IStableConfig.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../pools/interfaces/IPoolsConfig.sol";


contract Parameters
    {
	enum ParameterTypes {

		// PoolsConfig
		maximumWhitelistedPools,
		daoPercentShareInternalArbitrage,
		daoPercentShareExternalArbitrage,

		// StakingConfig
		minUnstakeWeeks,
		maxUnstakeWeeks,
		minUnstakePercent,
		modificationCooldown,

		// RewardsConfig
    	rewardsEmitterDailyPercentTimes1000,
		emissionsWeeklyPercentTimes1000,
		rewardsXSaltHoldersPercent,

		// StableConfig
		rewardPercentForCallingLiquidation,
		maxRewardValueForCallingLiquidation,
		minimumCollateralValueForBorrowing,
		initialCollateralRatioPercent,
		minimumCollateralRatioPercent,
		maximumLiquidationSlippagePercentTimes1000,
		percentSwapToUSDS,

		// DAOConfig
		bootstrappingRewards,
		percentPolRewardsBurned,
		baseBallotQuorumPercentTimes1000,
		ballotDuration,
		baseProposalCost,
		maxPendingTokensForWhitelisting,
		upkeepRewardPercentTimes1000
		}


	// If the parameter has an invalid parameterType then the call is a no-op
	function _executeParameterChange( ParameterTypes parameterType, bool increase, IPoolsConfig poolsConfig, IStakingConfig stakingConfig, IRewardsConfig rewardsConfig, IStableConfig stableConfig, IDAOConfig daoConfig ) internal
		{
		// PoolsConfig
		if ( parameterType == ParameterTypes.maximumWhitelistedPools )
			poolsConfig.changeMaximumWhitelistedPools( increase );
		else if ( parameterType == ParameterTypes.daoPercentShareInternalArbitrage )
			poolsConfig.changeDaoPercentShareInternalArbitrage( increase );
		else if ( parameterType == ParameterTypes.daoPercentShareExternalArbitrage )
			poolsConfig.changeDaoPercentShareExternalArbitrage( increase );

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
		else if ( parameterType == ParameterTypes.rewardsXSaltHoldersPercent )
			rewardsConfig.changeXSaltHoldersPercent(increase);

		// StableConfig
		else if ( parameterType == ParameterTypes.rewardPercentForCallingLiquidation )
			stableConfig.changeRewardPercentForCallingLiquidation(increase);
		else if ( parameterType == ParameterTypes.maxRewardValueForCallingLiquidation )
			stableConfig.changeMaxRewardValueForCallingLiquidation(increase);
		else if ( parameterType == ParameterTypes.minimumCollateralValueForBorrowing )
			stableConfig.changeMinimumCollateralValueForBorrowing(increase);
		else if ( parameterType == ParameterTypes.initialCollateralRatioPercent )
			stableConfig.changeInitialCollateralRatioPercent(increase);
		else if ( parameterType == ParameterTypes.minimumCollateralRatioPercent )
			stableConfig.changeMinimumCollateralRatioPercent(increase);
		else if ( parameterType == ParameterTypes.maximumLiquidationSlippagePercentTimes1000 )
			stableConfig.changeMaximumLiquidationSlippagePercentTimes1000(increase);
		else if ( parameterType == ParameterTypes.percentSwapToUSDS )
			stableConfig.changePercentSwapToUSDS(increase);

		// DAOConfig
		else if ( parameterType == ParameterTypes.bootstrappingRewards )
			daoConfig.changeBootstrappingRewards(increase);
		else if ( parameterType == ParameterTypes.percentPolRewardsBurned )
			daoConfig.changePercentPolRewardsBurned(increase);
		else if ( parameterType == ParameterTypes.baseBallotQuorumPercentTimes1000 )
			daoConfig.changeBaseBallotQuorumPercent(increase);
		else if ( parameterType == ParameterTypes.ballotDuration )
			daoConfig.changeBallotDuration(increase);
		else if ( parameterType == ParameterTypes.baseProposalCost )
			daoConfig.changeBaseProposalCost(increase);
		else if ( parameterType == ParameterTypes.maxPendingTokensForWhitelisting )
			daoConfig.changeMaxPendingTokensForWhitelisting(increase);
		else if ( parameterType == ParameterTypes.upkeepRewardPercentTimes1000 )
			daoConfig.changeUpkeepRewardPercent(increase);
		}
	}