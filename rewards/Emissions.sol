// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/access/Ownable.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "../Upkeepable.sol";


// Responsible for storing the SALT emissions and distributing them over time
contract Emissions is ReentrancyGuard, Upkeepable
    {
    constructor()
		{
		}


	function performUpkeep() internal override
		{
		}
	}
