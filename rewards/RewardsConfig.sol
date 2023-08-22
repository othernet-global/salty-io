// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/access/Ownable.sol";
import "./interfaces/IRewardsConfig.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract RewardsConfig is IRewardsConfig, Ownable
    {
	// The target daily percent rewards emitter distribution (from the SALT balance in each emitter contract).
	// Rewards Emitters distribute SALT rewards over time to the SharedRewards contracts where the rewards can be claimed by users.
	// Range: .25% to 2.5% with an adjustment of 0.25%
	uint256 public rewardsEmitterDailyPercentTimes1000 = 1000;  // Defaults to 1.0% with a 1000x multiplier

	// The weekly percent of SALT emissions that will be distributed from Emissions.sol to the Liquidity and xSALT Holder Reward Emitters.
	// Range: 0.25% to 1.0% with an adjustment of 0.25%
	uint256 public emissionsWeeklyPercentTimes1000 = 500;  // Defaults to 0.50% with a 1000x multiplier

	// By default, xSALT holders get 50% and liquidity providers get 50% of emissions and arbitrage profits
	// Range: 25% to 75% with an adjustment of 5%
    uint256 public stakingRewardsPercent = 50;

	// The percent of WBTC/WETH arbitrage profits (arbitrage swaps which involve WBTC/WETH which is most pairs) that will be sent to the SALT/USDS pool.
	// This is done as SALT/USDS while an important pair for the exchange isn't involved in any arbitrage swap cycles (which would yield arbitrage profit for it as well).
	// Range: 10% to 40% with an adjustment of 5%
    uint256 public percentRewardsSaltUSDS = 25;


	function changeRewardsEmitterDailyPercent(bool increase) public onlyOwner
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
        }

	function changeEmissionsWeeklyPercent(bool increase) public onlyOwner
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
        }


	function changeStakingRewardsPercent(bool increase) public onlyOwner
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
        }


	function changePercentRewardsSaltUSDS(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (percentRewardsSaltUSDS < 40)
                percentRewardsSaltUSDS = percentRewardsSaltUSDS + 5;
            }
        else
            {
            if (percentRewardsSaltUSDS > 10)
                percentRewardsSaltUSDS = percentRewardsSaltUSDS - 5;
            }
        }
    }