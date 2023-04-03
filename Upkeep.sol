// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "./openzeppelin/access/Ownable.sol";
import "./openzeppelin/security/ReentrancyGuard.sol";
import "./rewards/Profits.sol";

// Responsible for moving SALT rewards through the various contracts and into Staking.sol
// where they can claimed
// Can be called at any time, and offer 1% of the USDC stored in Profits.sol to the caller
contract Upkeep is ReentrancyGuard
    {
    Profits profits;
//    RewardsEmitter rewardsEmitter;
//    Emissions emissions;
//    Rewards rewards;


    constructor( address _profits )
		{
		profits = Profits( _profits );
		}


	function performUpkeep() public nonReentrant
		{
		profits.performUpkeep0();
		}



	// ===== VIEWS =====

	function currentUpkeepRewards() public view returns (uint256)
		{
		return profits.currentUpkeepRewards();
		}
	}
