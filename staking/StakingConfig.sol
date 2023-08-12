// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/access/Ownable.sol";
import "./interfaces/IStakingConfig.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract StakingConfig is IStakingConfig, Ownable
    {
	// The minimum number of weeks for an unstake request.
	// Range: 2 to 12 with an adjustment of 1
	uint256 public minUnstakeWeeks = 2;  // minUnstakePercent returned for unstaking this number of weeks

	// The maximum number of weeks for an unstake request.
	// Range: 14 to 52 with an adjustment of 2
	uint256 public maxUnstakeWeeks = 26; // 100% of the original SALT returned for unstaking this number of weeks

	// The minimum percentage of the original xSALT stake that is claimable when staking the minimum number of weeks.
	// Range: 25 to 75 with an adjustment of 5
	uint256 public minUnstakePercent = 50;

	// Minimum time between increasing and decreasing user share in SharedRewards contracts.
	// Prevents reward hunting where users could frontrun reward distributions and then immediately withdraw.
	// Range: 15 minutes to 6 hours with an adjustment of 15 minutes
	uint256 public modificationCooldown = 1 hours;


	function changeMinUnstakeWeeks(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (minUnstakeWeeks < 12)
                minUnstakeWeeks += 1;
            }
        else
            {
            if (minUnstakeWeeks > 2)
                minUnstakeWeeks -= 1;
            }
        }


	function changeMaxUnstakeWeeks(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (maxUnstakeWeeks < 52)
                maxUnstakeWeeks += 2;
            }
        else
            {
            if (maxUnstakeWeeks > 14)
                maxUnstakeWeeks -= 2;
            }
        }


	function changeMinUnstakePercent(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (minUnstakePercent < 75)
                minUnstakePercent += 5;
            }
        else
            {
            if (minUnstakePercent > 25)
                minUnstakePercent -= 5;
            }
        }


	function changeModificationCooldown(bool increase) public onlyOwner
        {
        if (increase)
            {
            if (modificationCooldown < 6 hours)
                modificationCooldown += 15 minutes;
            }
        else
            {
            if (modificationCooldown > 15 minutes)
                modificationCooldown -= 15 minutes;
            }
        }
    }