//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "./interfaces/IDAOConfig.sol";
//import "../rewards/interfaces/IRewardsConfig.sol";
//import "../stable/interfaces/IStableConfig.sol";
//import "../staking/interfaces/IStakingConfig.sol";
//
//
//contract Parameters
//    {
//	enum ParameterTypes {
//		bootstrappingRewards,
//		percentPolRewardsBurned,
//		baseBallotQuorumPercentSupplyTimes1000,
//		ballotDuration,
//		baseProposalCost,
//		maxPendingTokensForWhitelisting,
//		rewardsEmitterDailyPercentTimes1000,
//		upkeepRewardPercentTimes1000,
//		emissionsWeeklyPercentTimes1000,
//		emissionsXSaltHoldersPercent,
//		rewardPercentForCallingLiquidation,
//		maxRewardValueForCallingLiquidation,
//		minimumCollateralValueForBorrowing,
//		initialCollateralRatioPercent,
//		minimumCollateralRatioPercent,
//		minUnstakeWeeks,
//		maxUnstakeWeeks,
//		minUnstakePercent,
//		modificationCooldown,
//		maximumWhitelistedPools
//		}
//
//
//	// If the parameter has an invalid name then nothing happens
//	function _executeParameterChange( ParameterTypes parameterType, bool increase, IDAOConfig daoConfig, IRewardsConfig rewardsConfig, IStableConfig stableConfig, IStakingConfig stakingConfig ) internal
//		{
//		if ( parameterType == ParameterTypes.bootstrappingRewards )
//			daoConfig.changeBootstrappingRewards(increase);
//		else if ( parameterType == ParameterTypes.percentPolRewardsBurned )
//			daoConfig.changePercentPolRewardsBurned(increase);
//		else if ( parameterType == ParameterTypes.baseBallotQuorumPercentSupplyTimes1000 )
//			daoConfig.changeBaseBallotQuorumPercent(increase);
//		else if ( parameterType == ParameterTypes.ballotDuration )
//			daoConfig.changeBallotDuration(increase);
//		else if ( parameterType == ParameterTypes.baseProposalCost )
//			daoConfig.changeBaseProposalCost(increase);
//		else if ( parameterType == ParameterTypes.maxPendingTokensForWhitelisting )
//			daoConfig.changeMaxPendingTokensForWhitelisting(increase);
//		else if ( parameterType == ParameterTypes.upkeepRewardPercentTimes1000 )
//			daoConfig.changeUpkeepRewardPercent(increase);
//
//		else if ( parameterType == ParameterTypes.rewardsEmitterDailyPercentTimes1000 )
//			rewardsConfig.changeRewardsEmitterDailyPercent(increase);
//		else if ( parameterType == ParameterTypes.emissionsWeeklyPercentTimes1000 )
//			rewardsConfig.changeEmissionsWeeklyPercent(increase);
//		else if ( parameterType == ParameterTypes.emissionsXSaltHoldersPercent )
//			rewardsConfig.changeXSaltHoldersPercent(increase);
//
//		else if ( parameterType == ParameterTypes.rewardPercentForCallingLiquidation )
//			stableConfig.changeRewardPercentForCallingLiquidation(increase);
//		else if ( parameterType == ParameterTypes.maxRewardValueForCallingLiquidation )
//			stableConfig.changeMaxRewardValueForCallingLiquidation(increase);
//		else if ( parameterType == ParameterTypes.minimumCollateralValueForBorrowing )
//			stableConfig.changeMinimumCollateralValueForBorrowing(increase);
//		else if ( parameterType == ParameterTypes.initialCollateralRatioPercent )
//			stableConfig.changeInitialCollateralRatioPercent(increase);
//		else if ( parameterType == ParameterTypes.minimumCollateralRatioPercent )
//			stableConfig.changeMinimumCollateralRatioPercent(increase);
//
//		else if ( parameterType == ParameterTypes.minUnstakeWeeks )
//			stakingConfig.changeMinUnstakeWeeks(increase);
//		else if ( parameterType == ParameterTypes.maxUnstakeWeeks )
//			stakingConfig.changeMaxUnstakeWeeks(increase);
//		else if ( parameterType == ParameterTypes.minUnstakePercent )
//			stakingConfig.changeMinUnstakePercent(increase);
//		else if ( parameterType == ParameterTypes.modificationCooldown )
//			stakingConfig.changeModificationCooldown(increase);
//		else if ( parameterType == ParameterTypes.maximumWhitelistedPools )
//			stakingConfig.changeMaximumWhitelistedPools(increase);
//		}
//	}