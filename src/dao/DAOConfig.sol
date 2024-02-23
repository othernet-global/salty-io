// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IDAOConfig.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract DAOConfig is IDAOConfig, Ownable
    {
    event BootstrappingRewardsChanged(uint256 newBootstrappingRewards);
    event PercentPolRewardsBurnedChanged(uint256 newPercentPolRewardsBurned);
    event BaseBallotQuorumPercentChanged(uint256 newBaseBallotQuorumPercentTimes1000);
    event BallotDurationChanged(uint256 newBallotDuration);
    event BallotMaximumDurationChanged(uint256 newMaximumDuration);
    event RequiredProposalPercentStakeChanged(uint256 newRequiredProposalPercentStakeTimes1000);
    event PercentRewardsForReserveChanged(uint256 newArbitrageProfitsPercentPOL);
    event UpkeepRewardPercentChanged(uint256 newUpkeepRewardPercent);

	// The amount of SALT provided as a bootstrapping reward when a new token is whitelisted.
	// Note that new tokens will only be able to be whitelisted (even if the vote is favorable) once the DAO SALT balance is at least this amount.
	// The DAO receives 25 million SALT (linearly over 10 years - about 48k per week) as well as default ~23% of the Protocol Owned Liquidity SALT rewards.
	// Range: 50k ether to 500k ether with an adjustment of 50k ether
	uint256 public bootstrappingRewards = 200000 ether;

	// The percent of SALT rewards that are burned.
	// Range: 5% to 15% with an adjustment of 1%
    uint256 public percentRewardsBurned = 10;

	// The minimum amount of xSALT required for ballot quorum (to take action on the ballot).
	// baseBallotQuorum is decided as a percent of the total amount of SALT staked.
	// NOTE: there is a hard minimum of 1% of SALT.totalSupply that takes effect if the amount of staked SALT is low (at launch for instance).
	// Parameter adjustment quorum: = 1 * baseBallotQuorum
	// Token whitelisting quorum: = 2 * baseBallotQuorum
	// Sending SALT from the DAO quorum: = 3 * baseBallotQuorum
	// Country whitelisting quorum: = 3 * baseBallotQuorum
	// Contract updating quorum: = 3 * baseBallotQuorum
	// Website updating quorum: = 3 * baseBallotQuorum
	// Range: 5% to 20% with an adjustment of 1%
	uint256 public baseBallotQuorumPercentTimes1000 = 10 * 1000; // Default 10% of the total amount of SALT staked with a 1000x multiplier

	// How many days minimum a ballot has to exist before it can be taken action on.
	// Action will only be taken if it has the required votes and quorum to do so.
	// Range: 3 to 14 days with an adjustment of 1 day
	uint256 public ballotMinimumDuration = 10 days;

	// How many days a ballot can exist before it can be manually removed by any user.
	// Range: 15 to 90 days with an adjustment of 15 days
	uint256 public ballotMaximumDuration = 30 days;

	// The percent of staked SALT that a user has to have to make a proposal
	// Range: 0.10% to 2% with an adjustment of 0.10%
	uint256 public requiredProposalPercentStakeTimes1000 = 500;  // Defaults to 0.50% with a 1000x multiplier

	// The percentage of SALT rewards that are sent to the DAO's reserve
	// Range: 5% to 15% with an adjustment of 1%
	uint256 public percentRewardsForReserve = 10;

	// The share of the WETH arbitrage profits sent to the DAO that are sent to the caller of DAO.performUpkeep()
	// Range: 1% to 10% with an adjustment of 1%
	uint256 public upkeepRewardPercent = 5;


	function changeBootstrappingRewards(bool increase) external onlyOwner
		{
        if (increase)
        	{
            if (bootstrappingRewards < 500000 ether)
                bootstrappingRewards += 50000 ether;
            }
       	 else
       	 	{
            if (bootstrappingRewards > 50000 ether)
                bootstrappingRewards -= 50000 ether;
	        }

		emit BootstrappingRewardsChanged(bootstrappingRewards);
    	}


	function changePercentRewardsBurned(bool increase) external onlyOwner
		{
		if (increase)
			{
			if (percentRewardsBurned < 15)
				percentRewardsBurned += 1;
			}
		else
			{
			if (percentRewardsBurned > 5)
				percentRewardsBurned -= 1;
			}

		emit PercentPolRewardsBurnedChanged(percentRewardsBurned);
		}


	function changeBaseBallotQuorumPercent(bool increase) external onlyOwner
		{
		if (increase)
			{
			if (baseBallotQuorumPercentTimes1000 < 20 * 1000)
				baseBallotQuorumPercentTimes1000 += 1000;
			}
		else
			{
			if (baseBallotQuorumPercentTimes1000 > 5 * 1000 )
				baseBallotQuorumPercentTimes1000 -= 1000;
			}

		emit BaseBallotQuorumPercentChanged(baseBallotQuorumPercentTimes1000);
		}


	function changeBallotDuration(bool increase) external onlyOwner
    	{
        if (increase)
        	{
            if (ballotMinimumDuration < 14 days)
                ballotMinimumDuration += 1 days;
        	}
        else
        	{
            if (ballotMinimumDuration > 3 days)
                ballotMinimumDuration -= 1 days;
        	}

		emit BallotDurationChanged(ballotMinimumDuration);
    	}


	function changeBallotMaximumDuration(bool increase) external onlyOwner
    	{
        if (increase)
        	{
            if (ballotMaximumDuration < 90 days)
                ballotMaximumDuration += 15 days;
        	}
        else
        	{
            if (ballotMaximumDuration > 15 days)
                ballotMaximumDuration -= 15 days;
        	}

		emit BallotMaximumDurationChanged(ballotMaximumDuration);
    	}


	function changeRequiredProposalPercentStake(bool increase) external onlyOwner
		{
		if (increase)
			{
			if (requiredProposalPercentStakeTimes1000 < 2000) // Maximum 2%
				requiredProposalPercentStakeTimes1000 += 100; // Increase by 0.10%
			}
		else
			{
			if (requiredProposalPercentStakeTimes1000 > 100) // Minimum 0.10%
			   requiredProposalPercentStakeTimes1000 -= 100; // Decrease by 0.10%
			}

		emit RequiredProposalPercentStakeChanged(requiredProposalPercentStakeTimes1000);
		}


	function changePercentRewardsForReserve(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (percentRewardsForReserve < 15)
                percentRewardsForReserve += 1;
            }
        else
            {
            if (percentRewardsForReserve > 5)
                percentRewardsForReserve -= 1;
            }

		emit PercentRewardsForReserveChanged(percentRewardsForReserve);
		}


	function changeUpkeepRewardPercent(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (upkeepRewardPercent < 10)
                upkeepRewardPercent += 1;
            }
        else
            {
            if (upkeepRewardPercent > 1)
                upkeepRewardPercent -= 1;
            }

		emit UpkeepRewardPercentChanged(upkeepRewardPercent);
        }
    }