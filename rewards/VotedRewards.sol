// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/access/Ownable.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "./RewardsEmitter.sol";
import "../Upkeepable.sol";


// Stores SALT and distributes at upkeep it to RewardsEmitter.sol::rewards[poolID][true] based on the
// votes that each pool receives.
// Only the SALT since the last upkeep will be stored in the contract
contract VotedRewards is Ownable, ReentrancyGuard, Upkeepable
    {
	RewardsEmitter rewardsEmitter;


    constructor( address _rewardsEmitter )
		{
		setRewardsEmitter( _rewardsEmitter );
		}


	function setRewardsEmitter( address _rewardsEmitter ) public onlyOwner
		{
		rewardsEmitter = RewardsEmitter( _rewardsEmitter );
		}


	function performUpkeep() internal override
		{
		}
	}
