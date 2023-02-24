// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/access/Ownable.sol";
import "../openzeppelin/token/ERC20/ERC20.sol";


contract Config is Ownable
    {
	ERC20 public salt;

    // Changeable for debugging purposes to accelerate time
	uint256 public oneWeek = 5 minutes; // 1 weeks;

	uint256 public minUnstakePercent = 50;

	uint256 public minUnstakeWeeks = 2; // minUnstakePercent returned here
	uint256 public maxUnstakeWeeks = 26; // 100% staked returned here

	// Minimum time between deposits or withdrawals for each pool.
	// Prevents reward hunting where users could frontrun reward distributions and then immediately withdraw
	uint256 public depositWithdrawalCooldown = 1 hours;

	// Keeps track of what pools are valid
	address[] allPools;
	mapping(address=>uint256) poolValidity;												// [poolID]


	constructor( address _salt )
		{
		salt = ERC20( _salt );
		}


	function setSALT( address _salt ) public onlyOwner
		{
		salt = ERC20( _salt );
		}


	function whitelist( address poolID ) public onlyOwner
		{
		allPools.push( poolID );

		poolValidity[poolID] = 1;
		}


	function blacklist( address poolID ) public onlyOwner
		{
		poolValidity[poolID] = 0;
		}


	function setOneWeek( uint256 _oneWeek ) public onlyOwner
		{
		oneWeek = _oneWeek;
		}


	function setUnstakeParams( uint256 _minUnstakeWeeks, uint256 _maxUnstakeWeeks, uint256 _minUnstakePercent ) public onlyOwner
		{
		require( _minUnstakeWeeks < _maxUnstakeWeeks );

		minUnstakeWeeks = _minUnstakeWeeks;
		maxUnstakeWeeks = _maxUnstakeWeeks;

		minUnstakePercent = _minUnstakePercent;
		}


	function setDepositWithdrawalCooldown( uint256 _depositWithdrawalCooldown ) public onlyOwner
		{
		depositWithdrawalCooldown = _depositWithdrawalCooldown;
		}


	// ===== VIEWS =====
	function isValidPool( address poolID ) public view returns (bool)
		{
		return poolValidity[poolID] == 1;
		}


	function whitelistedPools() public view returns (address[] memory)
		{
		address[] memory valid = new address[](allPools.length);

		uint256 numValid = 0;
		for( uint256 i = 0; i < allPools.length; i++ )
			{
			address poolID = allPools[i];

			if ( isValidPool( poolID ) )
				valid[ numValid++ ] = poolID;
			}

		address[] memory valid2 = new address[](numValid);
		for( uint256 i = 0; i < numValid; i++ )
			valid2[i] = valid[i];

		return valid2;
		}
    }