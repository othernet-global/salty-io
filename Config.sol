// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "./openzeppelin/access/Ownable.sol";
import "./openzeppelin/token/ERC20/ERC20.sol";


contract Config is Ownable
    {
    // Changeable for debugging purposes to accelerate time
	uint256 public oneWeek = 5 minutes; // 1 weeks;

	uint256 public minUnstakeWeeks = 2;
	uint256 public maxUnstakeWeeks = 26; // 100% staked returned here

	// The percent of SALT returned when unstaking the minimum amount of time
	uint256 public minUnstakePercent = 50;

	// Minimum time between deposits or withdrawals for each pool.
	// Prevents reward hunting where users could frontrun reward distributions and then immediately withdraw
	uint256 public depositWithdrawalCooldown = 1 hours;

	// Keeps track of what pools are valid
	address[] allPools;
	mapping(address=>uint256) poolValidity;												// [poolID]

	// USDC - can be changed for debug purposes
	// Defaults to USDC on Polygon
	ERC20 public usdc = ERC20( 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 );

	// The share of the USDC stored in Profits.sol that is sent to the caller of Upkeep.performUpkeep()
	uint256 public upkeepPercent = 1 * 1000; // x1000 for precision


	constructor()
		{
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


	function setMinUnstakeWeeks( uint256 _minUnstakeWeeks ) public onlyOwner
		{
		require( _minUnstakeWeeks < maxUnstakeWeeks );

		minUnstakeWeeks = _minUnstakeWeeks;
		}


	function setMaxUnstakeWeeks( uint256 _maxUnstakeWeeks ) public onlyOwner
		{
		require( _maxUnstakeWeeks > minUnstakeWeeks );

		maxUnstakeWeeks = _maxUnstakeWeeks;
		}


	function setMinUnstakePercent( uint256 _minUnstakePercent ) public onlyOwner
		{
		minUnstakePercent = _minUnstakePercent;
		}


	function setDepositWithdrawalCooldown( uint256 _depositWithdrawalCooldown ) public onlyOwner
		{
		depositWithdrawalCooldown = _depositWithdrawalCooldown;
		}


	function setUSDC( address _usdc ) public onlyOwner
		{
		usdc = ERC20( _usdc );
		}


	// Should be multiplied by 1000 for precision
	function setUpkeepPercent( uint256 _upkeepPercent ) public onlyOwner
		{
		upkeepPercent = _upkeepPercent;
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



