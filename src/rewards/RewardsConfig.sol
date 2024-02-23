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

	// The target daily percent of rewards distributed by the stakingRewardsEmitter and liquidityRewardsEmitter (from the SALT balance in each emitter contract).
	// Rewards Emitters distribute SALT rewards over time to the SharedRewards contracts where the rewards can be claimed by users.
	// Range: .25% to 2.5% with an adjustment of 0.25%
	uint256 public rewardsEmitterDailyPercentTimes1000 = 750;  // Defaults to 0.75% with a 1000x multiplier

	// The weekly percent of SALT emissions that will be distributed from Emissions.sol to the Liquidity and xSALT Holder Reward Emitters.
	// Range: 0.25% to 1.0% with an adjustment of 0.25%
	uint256 public emissionsWeeklyPercentTimes1000 = 500;  // Defaults to 0.50% with a 1000x multiplier

	// By default, xSALT holders get 50% and liquidity providers get 50% of emissions and arbitrage profits sent to SaltRewards (after accounting for SALT/USDC rewards)
	// Range: 25% to 75% with an adjustment of 5%
    uint256 public stakingRewardsPercent = 50;


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
    }