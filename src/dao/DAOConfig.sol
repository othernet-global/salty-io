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
    event RequiredProposalPercentStakeChanged(uint256 newRequiredProposalPercentStakeTimes1000);
    event MaxPendingTokensForWhitelistingChanged(uint256 newMaxPendingTokensForWhitelisting);
    event ArbitrageProfitsPercentPOLChanged(uint256 newArbitrageProfitsPercentPOL);
    event UpkeepRewardPercentChanged(uint256 newUpkeepRewardPercent);

	// The amount of SALT provided as a bootstrapping reward when a new token is whitelisted.
	// Note that new tokens will only be able to be whitelisted (even if the vote is favorable) once the DAO SALT balance is at least this amount.
	// The DAO receives 25 million SALT (linearly over 10 years - about 48k per week) as well as default ~23% of the Protocol Owned Liquidity SALT rewards.
	// Range: 50k ether to 500k ether with an adjustment of 50k ether
	uint256 public bootstrappingRewards = 200000 ether;

	// For rewards distributed to the DAO, the percentage of SALT that is burned with the remaining staying in the DAO for later use.
	// Range: 25% to 75% with an adjustment of 5%
    uint256 public percentPolRewardsBurned = 50;

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

	// The percent of staked SALT that a user has to have to make a proposal
	// Range: 0.10% to 2% with an adjustment of 0.10%
	uint256 public requiredProposalPercentStakeTimes1000 = 500;  // Defaults to 0.50% with a 1000x multiplier

	// The maximum number of tokens that can be pending for whitelisting at any time.
	// Range: 3 to 12 with an adjustment of 1
	uint256 public maxPendingTokensForWhitelisting = 5;

	// The share of the WETH arbitrage profits that are sent to the DAO to form SALT/USDS Protocol Owned Liquidity
	// Range: 15% to 45% with an adjustment of 5%
	uint256 public arbitrageProfitsPercentPOL = 20;

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


	function changePercentPolRewardsBurned(bool increase) external onlyOwner
		{
		if (increase)
			{
			if (percentPolRewardsBurned < 75)
				percentPolRewardsBurned += 5;
			}
		else
			{
			if (percentPolRewardsBurned > 25)
				percentPolRewardsBurned -= 5;
			}

		emit PercentPolRewardsBurnedChanged(percentPolRewardsBurned);
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


	function changeMaxPendingTokensForWhitelisting(bool increase) external onlyOwner
		{
		if (increase)
			{
			if (maxPendingTokensForWhitelisting < 12)
				maxPendingTokensForWhitelisting += 1;
			}
		else
			{
			if (maxPendingTokensForWhitelisting > 3)
				maxPendingTokensForWhitelisting -= 1;
			}

		emit MaxPendingTokensForWhitelistingChanged(maxPendingTokensForWhitelisting);
		}


	function changeArbitrageProfitsPercentPOL(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (arbitrageProfitsPercentPOL < 45)
                arbitrageProfitsPercentPOL += 5;
            }
        else
            {
            if (arbitrageProfitsPercentPOL > 15)
                arbitrageProfitsPercentPOL -= 5;
            }

		emit ArbitrageProfitsPercentPOLChanged(arbitrageProfitsPercentPOL);
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