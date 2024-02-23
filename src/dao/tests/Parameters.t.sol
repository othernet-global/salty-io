// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "forge-std/Test.sol";
import "../Parameters.sol";
import "../../dev/Deployment.sol";
import "../DAOConfig.sol";
import "../../pools/PoolsConfig.sol";
import "../../staking/StakingConfig.sol";
import "../../rewards/RewardsConfig.sol";
import "../../ExchangeConfig.sol";
import "./TestParameters.sol";


contract TestParametersOffchain is Test
	{
	TestParameters public parameters;

	PoolsConfig public poolsConfig;
	StakingConfig public stakingConfig;
	RewardsConfig public rewardsConfig;
	ExchangeConfig public exchangeConfig;
	DAOConfig public daoConfig;

	Deployment public deployment = new Deployment();
	address public DEPLOYER;


	constructor()
		{
		DEPLOYER = deployment.DEPLOYER();

		parameters = new TestParameters();

		vm.startPrank(address(parameters));

		poolsConfig = new PoolsConfig();
		stakingConfig = new StakingConfig();
		rewardsConfig = new RewardsConfig();
		exchangeConfig = new ExchangeConfig(deployment.salt(), deployment.wbtc(), deployment.weth(), deployment.usdc(), deployment.usdt(), deployment.teamWallet());
		daoConfig = new DAOConfig();

		vm.stopPrank();
		}


	function _parameterValue( Parameters.ParameterTypes parameter ) internal view returns (uint256)
		{
		if ( parameter == Parameters.ParameterTypes.maximumWhitelistedPools )
			return poolsConfig.maximumWhitelistedPools();

		else if ( parameter == Parameters.ParameterTypes.minUnstakeWeeks )
			return stakingConfig.minUnstakeWeeks();
		else if ( parameter == Parameters.ParameterTypes.maxUnstakeWeeks )
			return stakingConfig.maxUnstakeWeeks();
		else if ( parameter == Parameters.ParameterTypes.minUnstakePercent )
			return stakingConfig.minUnstakePercent();
		else if ( parameter == Parameters.ParameterTypes.modificationCooldown )
			return stakingConfig.modificationCooldown();

		else if ( parameter == Parameters.ParameterTypes.rewardsEmitterDailyPercentTimes1000 )
			return rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.emissionsWeeklyPercentTimes1000 )
			return rewardsConfig.emissionsWeeklyPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.stakingRewardsPercent )
			return rewardsConfig.stakingRewardsPercent();


		else if ( parameter == Parameters.ParameterTypes.bootstrappingRewards )
			return daoConfig.bootstrappingRewards();
		else if ( parameter == Parameters.ParameterTypes.percentRewardsBurned )
			return daoConfig.percentRewardsBurned();
		else if ( parameter == Parameters.ParameterTypes.baseBallotQuorumPercentTimes1000 )
			return daoConfig.baseBallotQuorumPercentTimes1000();
		else if ( parameter == Parameters.ParameterTypes.ballotDuration )
			return daoConfig.ballotMinimumDuration();
		else if ( parameter == Parameters.ParameterTypes.requiredProposalPercentStakeTimes1000 )
			return daoConfig.requiredProposalPercentStakeTimes1000();
		else if ( parameter == Parameters.ParameterTypes.percentRewardsForReserve )
			return daoConfig.percentRewardsForReserve();
		else if ( parameter == Parameters.ParameterTypes.upkeepRewardPercent )
			return daoConfig.upkeepRewardPercent();
		else if ( parameter == Parameters.ParameterTypes.ballotMaximumDuration )
			return daoConfig.ballotMaximumDuration();

		require(false, "Invalid ParameterType" );
		return 0;
		}


	function _checkParameter( Parameters.ParameterTypes parameter, uint256 minValue, uint256 defaultValue, uint256 maxValue, uint256 change ) internal
		{
		assertEq( _parameterValue(parameter), defaultValue, "Default value is not as expected" );

		// Try increasing once
		parameters.executeParameterChange( parameter, true, poolsConfig, stakingConfig, rewardsConfig, daoConfig );

		uint256 expectedAfterIncrease = defaultValue + change;
		if ( expectedAfterIncrease > maxValue )
			expectedAfterIncrease = maxValue;

		assertEq( _parameterValue(parameter), expectedAfterIncrease, "Increased value is not as expected" );

		// Decrease once
		parameters.executeParameterChange( parameter, false, poolsConfig, stakingConfig, rewardsConfig, daoConfig );

		uint256 expectedAfterDecrease = expectedAfterIncrease - change;
		if ( expectedAfterDecrease < minValue )
			expectedAfterDecrease = minValue;

		if ( parameter != Parameters.ParameterTypes.minUnstakeWeeks )
			assertEq( _parameterValue(parameter), expectedAfterDecrease, "Decreased value is not as expected" );


		// Increase until max
		while( true )
			{
			parameters.executeParameterChange( parameter, true, poolsConfig, stakingConfig, rewardsConfig, daoConfig );
			if ( _parameterValue(parameter) >= maxValue )
				break;
			}

		// Increase one more time
		parameters.executeParameterChange( parameter, true, poolsConfig, stakingConfig, rewardsConfig, daoConfig );
		assertEq( _parameterValue(parameter), maxValue, "Max value not as expected" );


		// Decrease until min
		while( true )
			{
			parameters.executeParameterChange( parameter, false, poolsConfig, stakingConfig, rewardsConfig, daoConfig );
			if ( _parameterValue(parameter) <= minValue )
				break;
			}

		// Decrease one more time
		parameters.executeParameterChange( parameter, false, poolsConfig, stakingConfig, rewardsConfig, daoConfig );
		assertEq( _parameterValue(parameter), minValue, "Min value not as expected" );
		}


	function testPoolParameters() public
		{
		vm.startPrank(address(parameters));

		_checkParameter( Parameters.ParameterTypes.maximumWhitelistedPools, 20, 50, 100, 10 );
		}


	function testStakingParameters() public
		{
		vm.startPrank(address(parameters));

		_checkParameter( Parameters.ParameterTypes.minUnstakeWeeks, 2, 2, 12, 1 );
		_checkParameter( Parameters.ParameterTypes.maxUnstakeWeeks, 20, 52, 108, 8 );
		_checkParameter( Parameters.ParameterTypes.minUnstakePercent, 10, 20, 50, 5 );
		_checkParameter( Parameters.ParameterTypes.modificationCooldown, 15 minutes, 1 hours, 6 hours, 15 minutes );
		}


	function testRewardsParameters() public
		{
		vm.startPrank(address(parameters));

		_checkParameter( Parameters.ParameterTypes.rewardsEmitterDailyPercentTimes1000, 250, 1000, 2500, 250 );
		_checkParameter( Parameters.ParameterTypes.emissionsWeeklyPercentTimes1000, 250, 500, 1000, 250 );
		_checkParameter( Parameters.ParameterTypes.stakingRewardsPercent, 25, 50, 75, 5 );
		}


	function testDAOParameters() public
		{
		vm.startPrank(address(parameters));
		_checkParameter( Parameters.ParameterTypes.bootstrappingRewards, 50000 ether, 200000 ether, 500000 ether, 50000 ether );
		_checkParameter( Parameters.ParameterTypes.percentRewardsBurned, 5, 10, 15, 1 );
		_checkParameter( Parameters.ParameterTypes.baseBallotQuorumPercentTimes1000, 5000, 10000, 20000, 1000 );
		_checkParameter( Parameters.ParameterTypes.ballotDuration, 3 days, 10 days, 14 days, 1 days );
		_checkParameter( Parameters.ParameterTypes.requiredProposalPercentStakeTimes1000, 100, 500, 2000, 100 );
		_checkParameter( Parameters.ParameterTypes.percentRewardsForReserve, 5, 10, 15, 1 );
		_checkParameter( Parameters.ParameterTypes.upkeepRewardPercent, 1, 5, 10, 1 );
		_checkParameter( Parameters.ParameterTypes.ballotMaximumDuration, 15 days, 30 days, 90 days, 15 days );
		}
    }

