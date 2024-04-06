// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./launch/interfaces/IInitialDistribution.sol";
import "./rewards/interfaces/IRewardsEmitter.sol";
import "./interfaces/IExchangeConfig.sol";
import "./launch/interfaces/IAirdrop.sol";
import "./interfaces/IUpkeep.sol";

// Contract owned by the DAO with parameters modifiable only by the DAO
contract ExchangeConfig is IExchangeConfig, Ownable
    {
    event AccessManagerSet(IAccessManager indexed accessManager);

	ISalt immutable public salt;
	IERC20 immutable public wbtc;
	IERC20 immutable public weth;
	IERC20 immutable public usdc;
	IERC20 immutable public usdt;
	address immutable public teamWallet;

	IDAO public dao; // can only be set once
	IUpkeep public upkeep; // can only be set once
	IInitialDistribution public initialDistribution; // can only be set once

	// Gradually distribute SALT to the teamWallet and DAO over 10 years
	VestingWallet public teamVestingWallet;		// can only be set once
	VestingWallet public daoVestingWallet;		// can only be set once

	IAccessManager public accessManager;


	constructor( ISalt _salt, IERC20 _wbtc, IERC20 _weth, IERC20 _usdc, IERC20 _usdt, address _teamWallet )
		{
		salt = _salt;
		wbtc = _wbtc;
		weth = _weth;
		usdc = _usdc;
		usdt = _usdt;
		teamWallet = _teamWallet;
        }


	// setContracts can only be be called once - and is called at deployment time.
	function setContracts( IDAO _dao, IUpkeep _upkeep, IInitialDistribution _initialDistribution, VestingWallet _teamVestingWallet, VestingWallet _daoVestingWallet ) external onlyOwner
		{
		// setContracts is only called once (on deployment)
		require( address(dao) == address(0), "setContracts can only be called once" );

		dao = _dao;
		upkeep = _upkeep;
		initialDistribution = _initialDistribution;
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

		return accessManager.walletHasAccess( wallet );
		}
    }