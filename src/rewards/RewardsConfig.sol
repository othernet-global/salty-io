// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IRewardsConfig.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract RewardsConfig is IRewardsConfig, Ownable
    {
    event RewardsEmitterDailyPercentChanged(uint256 newRewardsEmitterDailyPercent);
    event EmissionsWeeklyPercentChanged(uint256 newEmissionsWeeklyPercent);
    event StakingRewardsPercentChanged(uint256 newStakingRewardsPercent);
    event PercentRewardsSaltUSDSChanged(uint256 newPercentRewardsSaltUSDS);

	// The target daily percent of rewards distributed by the stakingRewardsEmitter and liquidityRewardsEmitter (from the SALT balance in each emitter contract).
	// Rewards Emitters distribute SALT rewards over time to the SharedRewards contracts where the rewards can be claimed by users.
	// Range: .25% to 2.5% with an adjustment of 0.25%
	uint256 public rewardsEmitterDailyPercentTimes1000 = 1000;  // Defaults to 1.0% with a 1000x multiplier

	// The weekly percent of SALT emissions that will be distributed from Emissions.sol to the Liquidity and xSALT Holder Reward Emitters.
	// Range: 0.25% to 1.0% with an adjustment of 0.25%
	uint256 public emissionsWeeklyPercentTimes1000 = 500;  // Defaults to 0.50% with a 1000x multiplier

	// By default, xSALT holders get 50% and liquidity providers get 50% of emissions and arbitrage profits
	// Range: 25% to 75% with an adjustment of 5%
    uint256 public stakingRewardsPercent = 50;

	// The percent of SALT Rewards that will be sent to the SALT/USDS pool.
	// This is done as SALT/USDS while an important pair for the exchange isn't involved in any arbitrage swap cycles (which would yield arbitrage profit for it as well as all pools which take part in arbitrage take a share of the profit).
	// This is because it isn't part of the usual token/WBTC and token/WETH structure - which allows other pools to be part of arbitrage swap cycles when other pools are traded.
	// Range: 5% to 25% with an adjustment of 5%
    uint256 public percentRewardsSaltUSDS = 10;


	function changeRewardsEmitterDailyPercent(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (rewardsEmitterDailyPercentTimes1000 < 2500)
                rewardsEmitterDailyPercentTimes1000 = rewardsEmitterDailyPercentTimes1000 + 250;
            }
        else
            {
            if (rewardsEmitterDailyPercentTimes1000 > 250)
                rewardsEmitterDailyPercentTimes1000 = rewardsEmitterDailyPercentTimes1000 - 250;
            }

		emit RewardsEmitterDailyPercentChanged(rewardsEmitterDailyPercentTimes1000);
        }

	function changeEmissionsWeeklyPercent(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (emissionsWeeklyPercentTimes1000 < 1000)
                emissionsWeeklyPercentTimes1000 = emissionsWeeklyPercentTimes1000 + 250;
            }
        else
            {
            if (emissionsWeeklyPercentTimes1000 > 250)
                emissionsWeeklyPercentTimes1000 = emissionsWeeklyPercentTimes1000 - 250;
            }

		emit EmissionsWeeklyPercentChanged(emissionsWeeklyPercentTimes1000);
        }


	function changeStakingRewardsPercent(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (stakingRewardsPercent < 75)
                stakingRewardsPercent = stakingRewardsPercent + 5;
            }
        else
            {
            if (stakingRewardsPercent > 25)
                stakingRewardsPercent = stakingRewardsPercent - 5;
            }

		emit StakingRewardsPercentChanged(stakingRewardsPercent);
        }


	function changePercentRewardsSaltUSDS(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (percentRewardsSaltUSDS < 25)
                percentRewardsSaltUSDS = percentRewardsSaltUSDS + 5;
            }
        else
            {
            if (percentRewardsSaltUSDS > 5)
                percentRewardsSaltUSDS = percentRewardsSaltUSDS - 5;
            }

		emit PercentRewardsSaltUSDSChanged(percentRewardsSaltUSDS);
        }
    }