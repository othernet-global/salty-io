// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/access/Ownable.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "../Upkeepable.sol";
import "./RewardsEmitter.sol";
import "./RewardsConfig.sol";


// Stores SALT and distributes at upkeep it to RewardsEmitter.sol::rewards[poolID][true] based on the
// votes that each pool receives.
// Only stores the SALT rewards transferred in since the last upkeep.

contract VotedRewards is Ownable, ReentrancyGuard, Upkeepable
    {
	RewardsConfig rewardsConfig;


    constructor( address _rewardsConfig )
		{
		rewardsConfig = RewardsConfig( _rewardsConfig );
		}

	function performUpkeep() internal override
		{
		}
	}
