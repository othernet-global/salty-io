//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "forge-std/Test.sol";
//import "../Parameters.sol";
//import "../../stable/tests/IForcedPriceFeed.sol";
//import "../../rewards/RewardsConfig.sol";
//import "../../rewards/interfaces/IRewardsConfig.sol";
//import "../../staking/StakingConfig.sol";
//import "../../staking/interfaces/IStakingConfig.sol";
//import "../../stable/StableConfig.sol";
//import "../../stable/interfaces/IStableConfig.sol";
//import "..//DAOConfig.sol";
//import "../interfaces/IDAOConfig.sol";
//import "../../Salt.sol";
//import "../../stable/USDS.sol";
//
//contract TestParameters is Parameters, Test
//	{
//	IForcedPriceFeed public _forcedPriceFeed = IForcedPriceFeed(address(0xDEE776893503EFB20e6fC7173E9c03911F28233E));
//
//	IDAOConfig public _daoConfig = new DAOConfig();
//	IRewardsConfig public _rewardsConfig = new RewardsConfig();
//	IStableConfig public _stableConfig = new StableConfig(IPriceFeed(address(_forcedPriceFeed)));
//	IStakingConfig public _stakingConfig = IStakingConfig(address(new StakingConfig(IERC20(address(new Salt())))));
//
//
//	constructor()
//		{
//		}
//
//
//    function setUp() public
//    	{
//    	}
//
//
//	function valueForName( string memory name ) public returns (uint256)
//		{
//		bytes32 nameHash = keccak256(bytes( name ) );
//
//		if ( nameHash == keccak_bootstrappingRewards )
//			return _daoConfig.bootstrappingRewards();
//		else if ( nameHash == keccak_percentPolRewardsBurned )
//			return _daoConfig.percentPolRewardsBurned();
//		else if ( nameHash == keccak_baseBallotQuorumPercentSupplyTimes1000 )
//			return _daoConfig.baseBallotQuorumPercentSupplyTimes1000();
//		else if ( nameHash == keccak_ballotDuration )
//			return _daoConfig.ballotDuration();
//		else if ( nameHash == keccak_baseProposalCost )
//			return _daoConfig.baseProposalCost();
//		else if ( nameHash == keccak_maxPendingTokensForWhitelisting )
//			return _daoConfig.maxPendingTokensForWhitelisting();
//
//		else if ( nameHash == keccak_rewardsEmitterDailyPercentTimes1000 )
//			return _rewardsConfig.rewardsEmitterDailyPercentTimes1000();
//		else if ( nameHash == keccak_upkeepRewardPercentTimes1000 )
//			return _rewardsConfig.upkeepRewardPercentTimes1000();
//		else if ( nameHash == keccak_emissionsWeeklyPercentTimes1000 )
//			return _rewardsConfig.emissionsWeeklyPercentTimes1000();
//		else if ( nameHash == keccak_emissionsXSaltHoldersPercent )
//			return _rewardsConfig.emissionsXSaltHoldersPercent();
//
//		else if ( nameHash == keccak_rewardPercentForCallingLiquidation )
//			return _stableConfig.rewardPercentForCallingLiquidation();
//		else if ( nameHash == keccak_maxRewardValueForCallingLiquidation )
//			return _stableConfig.maxRewardValueForCallingLiquidation();
//		else if ( nameHash == keccak_minimumCollateralValueForBorrowing )
//			return _stableConfig.minimumCollateralValueForBorrowing();
//		else if ( nameHash == keccak_initialCollateralRatioPercent )
//			return _stableConfig.initialCollateralRatioPercent();
//		else if ( nameHash == keccak_minimumCollateralRatioPercent )
//			return _stableConfig.minimumCollateralRatioPercent();
//
//		else if ( nameHash == keccak_minUnstakeWeeks )
//			return _stakingConfig.minUnstakeWeeks();
//		else if ( nameHash == keccak_maxUnstakeWeeks )
//			return _stakingConfig.maxUnstakeWeeks();
//		else if ( nameHash == keccak_minUnstakePercent )
//			return _stakingConfig.minUnstakePercent();
//		else if ( nameHash == keccak_modificationCooldown )
//			return _stakingConfig.modificationCooldown();
//		else if ( nameHash == keccak_maximumWhitelistedPools )
//			return _stakingConfig.maximumWhitelistedPools();
//		else
//			require( false, "Invalid nameHash" );
//
//		return 0;
//		}
//
//
//	function _checkParameter( string memory name, uint256 minValue, uint256 defaultValue, uint256 maxValue, uint256 change ) internal
//		{
//		bytes32 nameHash = keccak256(bytes( name ) );
//
//		assertEq( valueForName(name), defaultValue, "Default value is not as expected" );
//
//		// Try increasing once
//		_executeParameterIncrease( nameHash, _daoConfig, _rewardsConfig, _stableConfig, _stakingConfig );
//
//		uint256 expectedAfterIncrease = defaultValue + change;
//		if ( expectedAfterIncrease > maxValue )
//			expectedAfterIncrease = maxValue;
//
//		assertEq( valueForName(name), expectedAfterIncrease, "Increased value is not as expected" );
//
//		// Decrease once
//		_executeParameterDecrease( nameHash, _daoConfig, _rewardsConfig, _stableConfig, _stakingConfig );
//
//		uint256 expectedAfterDecrease = expectedAfterIncrease - change;
//		if ( expectedAfterDecrease < minValue )
//			expectedAfterDecrease = minValue;
//
//		assertEq( valueForName(name), expectedAfterDecrease, "Decreased value is not as expected" );
//
//
//		// Increase until max
//		while( true )
//			{
//			_executeParameterIncrease( nameHash, _daoConfig, _rewardsConfig, _stableConfig, _stakingConfig );
//			if ( valueForName(name) >= maxValue )
//				break;
//			}
//
//		// Increase one more time
//		_executeParameterIncrease( nameHash, _daoConfig, _rewardsConfig, _stableConfig, _stakingConfig );
//		assertEq( valueForName(name), maxValue, "Max value not as expected" );
//
//
//		// Decrease until min
//		while( true )
//			{
//			_executeParameterDecrease( nameHash, _daoConfig, _rewardsConfig, _stableConfig, _stakingConfig );
//			if ( valueForName(name) <= minValue )
//				break;
//			}
//
//		// Decrease one more time
//		_executeParameterDecrease( nameHash, _daoConfig, _rewardsConfig, _stableConfig, _stakingConfig );
//		assertEq( valueForName(name), minValue, "Min value not as expected" );
//		}
//
//
//	function testDAOParameters() public
//		{
//		_checkParameter( "bootstrappingRewards", 50000 ether, 100000 ether, 500000 ether, 50000 ether );
//		_checkParameter( "percentPolRewardsBurned", 25, 50, 75, 5 );
//		_checkParameter( "baseBallotQuorumPercentSupplyTimes1000", 1000, 1000, 5000, 250 );
//		_checkParameter( "ballotDuration", 3 days, 7 days, 14 days, 1 days );
//		_checkParameter( "baseProposalCost", 100 ether, 500 ether, 2000 ether, 100 ether );
//		_checkParameter( "maxPendingTokensForWhitelisting", 3, 5, 12, 1 );
//		}
//
//
//	function testRewardsParameters() public
//		{
//		_checkParameter( "emissionsWeeklyPercentTimes1000", 250, 500, 1000, 250 );
//		_checkParameter( "emissionsXSaltHoldersPercent", 25, 50, 75, 5 );
//		_checkParameter( "rewardsEmitterDailyPercentTimes1000", 500, 1000, 2500, 250 );
//		_checkParameter( "upkeepRewardPercentTimes1000", 1000, 5000, 10000, 500 );
//		}
//
//
//	function testStableParameters() public
//		{
//		// Need to increase minimumCollateralRatioPercent as minimumCollateralRatioPercent - rewardPercentForCallingLiquidation has to be greater than 105
//		for( uint256 i = 0; i < 5; i++ )
//			_stableConfig.increaseMinimumCollateralRatioPercent();
//
//		_checkParameter( "rewardPercentForCallingLiquidation", 5, 5, 10, 1 );
//
//		// Back to the default
//		for( uint256 i = 0; i < 5; i++ )
//			_stableConfig.decreaseMinimumCollateralRatioPercent();
//
//		_checkParameter( "maxRewardValueForCallingLiquidation", 100 ether, 300 ether, 500 ether, 50 ether );
//		_checkParameter( "minimumCollateralValueForBorrowing", 1000 ether, 2500 ether, 5000 ether, 500 ether );
//		_checkParameter( "initialCollateralRatioPercent", 150, 200, 300, 25 );
//		_checkParameter( "minimumCollateralRatioPercent", 110, 110, 120, 1 );
//		}
//
//
//	function testStakingParameters() public
//		{
//		_checkParameter( "minUnstakeWeeks", 2, 2, 12, 1 );
//		_checkParameter( "maxUnstakeWeeks", 14, 26, 52, 2 );
//		_checkParameter( "minUnstakePercent", 25, 50, 75, 5 );
//		_checkParameter( "modificationCooldown", 15 minutes, 1 hours, 6 hours, 15 minutes );
//		_checkParameter( "maximumWhitelistedPools", 20, 50, 100, 10 );
//		}
//    }
//
