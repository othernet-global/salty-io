// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/access/Ownable2Step.sol";
import "../openzeppelin/token/ERC20/IERC20.sol";
import "../openzeppelin/utils/structs/EnumerableSet.sol";
import "./IStaking.sol";


contract StakingConfig is Ownable2Step, IStaking
    {
	// The maximum number of whitelisted pools that can exist simultaneously
	uint256 constant public MAXIMUM_WHITELISTED_POOLS = 100;

	IERC20 immutable public salt;

	// Salty DAO - the address of the Salty.IO DAO (which holds the protocol liquidity)
	address immutable public saltyDAO;

	// Early Unstake Handler - early unstake fees are sent here and then distributed on upkeep
	address public earlyUnstake;

	uint256 public minUnstakePercent = 50;

	uint256 public minUnstakeWeeks = 2; // minUnstakePercent returned here
	uint256 public maxUnstakeWeeks = 26; // 100% staked returned here

	// Minimum time between deposits or withdrawals for each pool.
	// Prevents reward hunting where users could frontrun reward distributions and then immediately withdraw
	uint256 public depositWithdrawalCooldown = 1 hours;

	// Keeps track of what pools have been whitelisted
	EnumerableSet.AddressSet private _whitelist;


	constructor( address _salt, address _saltyDAO )
		{
		salt = IERC20( _salt );
		saltyDAO = _saltyDAO;
		}


	function setEarlyUnstake( address _earlyUnstake ) public onlyOwner
		{
		earlyUnstake = _earlyUnstake;

		emit eSetEarlyUnstake( earlyUnstake);
		}


	function whitelist( address poolID ) public onlyOwner
		{
		require( _whitelist.length() < MAXIMUM_WHITELISTED_POOLS, "Maximum number of whitelisted pools already reached" );

		// Don't allow whitelisting the STAKING pool as it will be made valid by default
		// and not returned in whitelistedPools()
		require( poolID != address(0), "Cannot whitelist poolID 0" );

		_whitelist.add( poolID );

		emit eWhitelist( poolID );
		}


	function blacklist( address poolID ) public onlyOwner
		{
		_whitelist.remove( poolID );

		emit eBlacklist( poolID );
		}


	function setUnstakeParams( uint256 _minUnstakeWeeks, uint256 _maxUnstakeWeeks, uint256 _minUnstakePercent ) public onlyOwner
		{
		require( _minUnstakeWeeks >=2, "minUnstakeWeeks too small" );
		require( _minUnstakeWeeks <=12, "minUnstakeWeeks too large" );
		require( _maxUnstakeWeeks >=13, "maxUnstakeWeeks too small" );
		require( _maxUnstakeWeeks <=52, "maxUnstakeWeeks too large" );
		require( _minUnstakePercent >=25, "minUnstakePercent too small" );
		require( _minUnstakePercent <=75, "minUnstakePercent too large" );

		minUnstakeWeeks = _minUnstakeWeeks;
		maxUnstakeWeeks = _maxUnstakeWeeks;

		minUnstakePercent = _minUnstakePercent;


		emit eSetUnstakeParams( minUnstakeWeeks, maxUnstakeWeeks, minUnstakePercent );
		}


	function setDepositWithdrawalCooldown( uint256 _depositWithdrawalCooldown ) public onlyOwner
		{
		depositWithdrawalCooldown = _depositWithdrawalCooldown;

		emit eSetCooldown( depositWithdrawalCooldown );
		}


	// ===== VIEWS =====

	function numberOfWhitelistedPools() public view returns (uint256)
		{
		return _whitelist.length();
		}


	// This does not include the 0 poolID for generic staked SALT (not deposited to any pool)
	function whitelistedPoolAtIndex( uint256 index ) public view returns (address)
		{
		return _whitelist.at( index );
		}


	function isValidPool( address poolID ) public view returns (bool)
		{
		if ( poolID == address(0) ) // STAKING?
			return true;

		return _whitelist.contains( poolID );
		}


	// This does not include the 0 poolID for generic staked SALT (not deposited to any pool)
	function whitelistedPools() public view returns (address[] memory)
		{
		return _whitelist.values();
		}
    }