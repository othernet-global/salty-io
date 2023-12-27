// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./launch/interfaces/IInitialDistribution.sol";
import "./rewards/interfaces/IRewardsEmitter.sol";
import "./interfaces/IExchangeConfig.sol";
import "./launch/interfaces/IAirdrop.sol";
import "./interfaces/IUpkeep.sol";
import "./interfaces/IManagedWallet.sol";

// Contract owned by the DAO with parameters modifiable only by the DAO
contract ExchangeConfig is IExchangeConfig, Ownable
    {
    event AccessManagerSet(IAccessManager indexed accessManager);

	ISalt immutable public salt;
	IERC20 immutable public wbtc;
	IERC20 immutable public weth;
	IERC20 immutable public dai;
	IUSDS immutable public usds;
	IManagedWallet immutable public managedTeamWallet;

	IDAO public dao; // can only be set once
	IUpkeep public upkeep; // can only be set once
	IInitialDistribution public initialDistribution; // can only be set once
	IAirdrop public airdrop; // can only be set once

	// Gradually distribute SALT to the teamWallet and DAO over 10 years
	VestingWallet public teamVestingWallet;		// can only be set once
	VestingWallet public daoVestingWallet;		// can only be set once

	IAccessManager public accessManager;


	constructor( ISalt _salt, IERC20 _wbtc, IERC20 _weth, IERC20 _dai, IUSDS _usds, IManagedWallet _managedTeamWallet )
		{
		salt = _salt;
		wbtc = _wbtc;
		weth = _weth;
		dai = _dai;
		usds = _usds;
		managedTeamWallet = _managedTeamWallet;
        }


	// setContracts can only be be called once - and is called at deployment time.
	function setContracts( IDAO _dao, IUpkeep _upkeep, IInitialDistribution _initialDistribution, IAirdrop _airdrop, VestingWallet _teamVestingWallet, VestingWallet _daoVestingWallet ) external onlyOwner
		{
		// setContracts is only called once (on deployment)
		require( address(dao) == address(0), "setContracts can only be called once" );

		dao = _dao;
		upkeep = _upkeep;
		initialDistribution = _initialDistribution;
		airdrop = _airdrop;
		teamVestingWallet = _teamVestingWallet;
		daoVestingWallet = _daoVestingWallet;
		}


	function setAccessManager( IAccessManager _accessManager ) external onlyOwner
		{
		require( address(_accessManager) != address(0), "_accessManager cannot be address(0)" );

		accessManager = _accessManager;

	    emit AccessManagerSet(_accessManager);
		}


	// Provide access to the protocol components using the AccessManager to determine if a wallet should have access.
	// AccessManager can be updated by the DAO and include any necessary functionality.
	function walletHasAccess( address wallet ) external view returns (bool)
		{
		// The DAO contract always has access (needed to form POL)
		if ( wallet == address(dao) )
			return true;

		// The Airdrop contract always has access (needed to stake SALT)
		if ( wallet == address(airdrop) )
			return true;

		return accessManager.walletHasAccess( wallet );
		}
    }