// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../SaltRewards.sol";


contract TestSaltRewards is SaltRewards
    {
    constructor( IRewardsEmitter _stakingRewardsEmitter, IRewardsEmitter _liquidityRewardsEmitter, IExchangeConfig _exchangeConfig, IRewardsConfig _rewardsConfig )
    SaltRewards( _stakingRewardsEmitter, _liquidityRewardsEmitter, _exchangeConfig, _rewardsConfig )
		{
		}



	// Send the pending SALT rewards to the stakingRewardsEmitter
	function sendStakingRewards(uint256 stakingRewardsAmount) public
		{
		_sendStakingRewards(stakingRewardsAmount);
		}


	// Transfer SALT rewards to the liquidityRewardsEmitter proportional to pool shares in generating recent arb profits.
	function sendLiquidityRewards( uint256 liquidityRewardsAmount, uint256 directSaltUSDSRewardsAmount, bytes32[] memory poolIDs, uint256[] memory profitsForPools ) public
		{
		uint256 totalProfits = 0;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			totalProfits += profitsForPools[i];

		_sendLiquidityRewards( liquidityRewardsAmount, directSaltUSDSRewardsAmount, poolIDs, profitsForPools, totalProfits );
		}


	function sendInitialLiquidityRewards( uint256 liquidityBootstrapAmount, bytes32[] memory poolIDs ) public
		{
		_sendInitialLiquidityRewards( liquidityBootstrapAmount, poolIDs );
		}


	function sendInitialStakingRewards( uint256 stakingBootstrapAmount ) public
		{
		_sendInitialStakingRewards(stakingBootstrapAmount);
		}
	}
