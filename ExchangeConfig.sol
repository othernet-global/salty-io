// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "./openzeppelin/access/Ownable.sol";
import "./interfaces/IExchangeConfig.sol";
import "./rewards/interfaces/IRewardsEmitter.sol";
import "./rewards/interfaces/ISaltRewards.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract ExchangeConfig is IExchangeConfig, Ownable
    {
	ISalt immutable public salt;
	IERC20 immutable public wbtc;
	IERC20 immutable public weth;
	IERC20 immutable public usdc;
	IUSDS immutable public usds;

	IDAO public dao; // can only be set once
	IRewardsEmitter public stakingRewardsEmitter;
	IRewardsEmitter public liquidityRewardsEmitter;
	IAccessManager public accessManager;


	constructor( ISalt _salt, IERC20 _wbtc, IERC20 _weth, IERC20 _usdc, IUSDS _usds )
		{
		require( address(_salt) != address(0), "_salt cannot be address(0)" );
		require( address(_wbtc) != address(0), "_wbtc cannot be address(0)" );
		require( address(_weth) != address(0), "_weth cannot be address(0)" );
		require( address(_usdc) != address(0), "_usdc cannot be address(0)" );
		require( address(_usds) != address(0), "_usds cannot be address(0)" );

		salt = _salt;
		wbtc = _wbtc;
		weth = _weth;
		usdc = _usdc;
		usds = _usds;
        }


	function setDAO( IDAO _dao ) public onlyOwner
		{
		require( address(dao) == address(0), "setDAO can only be called once" );
		require( address(_dao) != address(0), "_dao cannot be address(0)" );

		dao = _dao;
		}


	function setAccessManager( IAccessManager _accessManager ) public onlyOwner
		{
		require( address(_accessManager) != address(0), "_accessManager cannot be address(0)" );

		accessManager = _accessManager;
		}


	function setStakingRewardsEmitter( IRewardsEmitter _rewardsEmitter ) public onlyOwner
		{
		require( address(_rewardsEmitter) != address(0), "_rewardsEmitter cannot be address(0)" );

		stakingRewardsEmitter = _rewardsEmitter;
		}


	function setLiquidityRewardsEmitter( IRewardsEmitter _rewardsEmitter ) public onlyOwner
		{
		require( address(_rewardsEmitter) != address(0), "_rewardsEmitter cannot be address(0)" );

		liquidityRewardsEmitter = _rewardsEmitter;
		}


	// Provide access to the protocol components that require it and then look to the AccessManager to determine if a wallet should have access.
	function walletHasAccess( address wallet ) public view returns (bool)
		{
		// The dao should always have access, even if it didn't register with the AccessManager
		if ( wallet == address(dao) )
			return true;

		return accessManager.walletHasAccess( wallet );
		}
    }