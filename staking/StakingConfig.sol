// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/access/Ownable2Step.sol";
import "../openzeppelin/token/ERC20/IERC20.sol";
import "./IStaking.sol";


contract StakingConfig is Ownable2Step, IStaking
    {
	// The maximum number of whitelisted pools that can exist simulataneously
	uint256 public MAXIMUM_WHITELISTED_POOLS = 200;


	IERC20 immutable public salt;

	// Salty Protocol Owned Liquidity - the address holding the protocol liquidity
	// Can only be changed after a one week delay
	address public saltyPOL;
	address public pendingSaltyPOL;
	uint256 public pendingSaltyTimestamp;

	// Early Unstake Handler - early unstake fees are sent here and then distributed on upkeep
	address public earlyUnstake;

	uint256 public minUnstakePercent = 50;

	uint256 public minUnstakeWeeks = 2; // minUnstakePercent returned here
	uint256 public maxUnstakeWeeks = 26; // 100% staked returned here

	// Minimum time between deposits or withdrawals for each pool.
	// Prevents reward hunting where users could frontrun reward distributions and then immediately withdraw
	uint256 public depositWithdrawalCooldown = 1 hours;

	// Keeps track of what pools are valid
	address[] allPools;
	mapping(address=>bool) poolAdded;													// [poolID]
	mapping(address=>uint256) poolWhitelisted;										// [poolID]

	bool public xsaltIsTransferable = true;


	constructor( address _salt, address _saltyPOL )
		{
		salt = IERC20( _salt );
		saltyPOL = _saltyPOL;
		}


	function setXSALTIsTransferable( bool _transferable ) public onlyOwner
		{
		xsaltIsTransferable = _transferable;

		emit eSetTransferable( xsaltIsTransferable );
		}


	// Time delay change for SaltyPOL as changing this would allow the staked SALT
	// and SALT/USDC held by Salty.IO to be withdrawn / moved
	function initChangeSaltyPOL( address _saltyPOL ) public onlyOwner
		{
		pendingSaltyPOL = _saltyPOL;
		pendingSaltyTimestamp = block.timestamp + 7 days;

		emit eChangePOL( pendingSaltyPOL );
		}


	function confirmChangeSaltyPOL() public onlyOwner
		{
		require( block.timestamp >= pendingSaltyTimestamp );
		require( pendingSaltyPOL != address(0), "SaltyPOL cannot be the zero address" );

		saltyPOL = pendingSaltyPOL;

		emit eConfirmPOL();
		}


	function setEarlyUnstake( address _earlyUnstake ) public onlyOwner
		{
		earlyUnstake = _earlyUnstake;

		emit eSetEarlyUnstake( earlyUnstake);
		}


	function whitelist( address poolID ) public onlyOwner
		{
		// Don't allow whitelisting the STAKING pool as it will be made valid by default
		// and not returned in whitelistedPools()
		require( poolID != address(0), "Cannot whitelist poolID 0" );

		address[] memory existingPools = whitelistedPools();
		require( existingPools.length < MAXIMUM_WHITELISTED_POOLS, "Maximum number of whitelisted pools already reached" );

		// Make sure the pool hasn't already been added to allPools
		if ( ! poolAdded[poolID] )
			{
			allPools.push( poolID );
			poolAdded[poolID] = true;
			}

		poolWhitelisted[poolID] = 1;

		emit eWhitelist( poolID );
		}


	function blacklist( address poolID ) public onlyOwner
		{
		poolWhitelisted[poolID] = 0;

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
	function isValidPool( address poolID ) public view returns (bool)
		{
		if ( poolID == address(0) ) // STAKING?
			return true;

		return poolWhitelisted[poolID] == 1;
		}


	// This does not include the 0 poolID for generic staked SALT (not deposited to any pool)
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