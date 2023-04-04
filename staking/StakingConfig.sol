// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../openzeppelin/access/Ownable2Step.sol";
import "../openzeppelin/token/ERC20/IERC20.sol";
import "../openzeppelin/utils/structs/EnumerableSet.sol";
import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
import "./IStaking.sol";
import "./IStakingConfig.sol";

contract StakingConfig is Ownable2Step, IStaking
    {
    using EnumerableSet for EnumerableSet.AddressSet;


	// The maximum number of whitelisted pools that can exist simultaneously
	uint256 constant public MAXIMUM_WHITELISTED_POOLS = 100;

	IERC20 immutable public salt;

    // The time period for one week - which can be made shorter for debugging convenience
	uint256 public oneWeek;

	UnstakeParams public unstakeParams;

	// Salty DAO - the address of the Salty.IO DAO (which holds the protocol liquidity)
	address immutable public saltyDAO;

	// Early Unstake Handler - early unstake fees are sent here and then distributed on upkeep
	address public earlyUnstake;

	// Minimum time between deposits or withdrawals for each pool.
	// Prevents reward hunting where users could frontrun reward distributions and then immediately withdraw
	uint256 public depositWithdrawalCooldown = 1 hours;

	// Keeps track of what pools have been whitelisted
	EnumerableSet.AddressSet private _whitelist;

    // A special poolID which represents staked SALT and allows for general staking rewards
    // that are not tied to a specific pool
    IUniswapV2Pair public constant STAKING = IUniswapV2Pair(address(0));


	constructor( IERC20 _salt, address _saltyDAO, uint256 _oneWeek )
		{
		salt = IERC20( _salt );
		saltyDAO = _saltyDAO;
		oneWeek = _oneWeek;

		unstakeParams = UnstakeParams( 2, 26, 50 );
		}


	function setEarlyUnstake( address _earlyUnstake ) public onlyOwner
		{
		if ( earlyUnstake != _earlyUnstake )
			emit eSetEarlyUnstake( earlyUnstake);

		earlyUnstake = _earlyUnstake;
		}


	function whitelist( IUniswapV2Pair poolID ) public onlyOwner
		{
		require( _whitelist.length() < MAXIMUM_WHITELISTED_POOLS, "Maximum number of whitelisted pools already reached" );

		// Don't allow whitelisting the STAKING pool as it will be made valid by default
		// and not returned in whitelistedPools()
		require( poolID != STAKING, "Cannot whitelist poolID 0" );

		if ( _whitelist.add( address(poolID) ) )
			emit eWhitelist( poolID );
		}


	function unwhitelist( IUniswapV2Pair poolID ) public onlyOwner
		{
		if ( _whitelist.remove( address(poolID) ) )
			emit eUnwhitelist( poolID );
		}


	function setUnstakeParams( uint256 _minUnstakeWeeks, uint256 _maxUnstakeWeeks, uint256 _minUnstakePercent ) public onlyOwner
		{
		require( _minUnstakeWeeks >=2, "minUnstakeWeeks too small" );
		require( _minUnstakeWeeks <=12, "minUnstakeWeeks too large" );

		require( _maxUnstakeWeeks >=13, "maxUnstakeWeeks too small" );
		require( _maxUnstakeWeeks <=52, "maxUnstakeWeeks too large" );

		require( _minUnstakePercent >=25, "minUnstakePercent too small" );
		require( _minUnstakePercent <=75, "minUnstakePercent too large" );

		unstakeParams = UnstakeParams( _minUnstakeWeeks, _maxUnstakeWeeks, _minUnstakePercent );

		emit eSetUnstakeParams( _minUnstakeWeeks, _maxUnstakeWeeks, _minUnstakePercent );
		}


	function setDepositWithdrawalCooldown( uint256 _depositWithdrawalCooldown ) public onlyOwner
		{
		if ( depositWithdrawalCooldown != _depositWithdrawalCooldown )
			emit eSetCooldown( depositWithdrawalCooldown );

		depositWithdrawalCooldown = _depositWithdrawalCooldown;
		}


	// ===== VIEWS =====

	function numberOfWhitelistedPools() public view returns (uint256)
		{
		return _whitelist.length();
		}


	// This does not include the 0 poolID for generic staked SALT (not deposited to any pool)
	function whitelistedPoolAtIndex( uint256 index ) public view returns (IUniswapV2Pair)
		{
		return IUniswapV2Pair( _whitelist.at( index ) );
		}


	function isValidPool( IUniswapV2Pair poolID ) public view returns (bool)
		{
		if ( poolID == STAKING )
			return true;

		return _whitelist.contains( address(poolID) );
		}


	// This does not include the STAKING poolID for generic staked SALT (not deposited to any pool)
	function whitelistedPools() public view returns (IUniswapV2Pair[] memory)
		{
		address[] memory pools0 = _whitelist.values();

		IUniswapV2Pair[] memory pools = new IUniswapV2Pair[]( pools0.length );

		for( uint256 i = 0; i < pools.length; i++ )
			pools[i] = IUniswapV2Pair( pools0[i] );

		return pools;
		}
    }