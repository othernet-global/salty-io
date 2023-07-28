// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "./openzeppelin/access/Ownable.sol";
import "./interfaces/IExchangeConfig.sol";
import "./rewards/interfaces/IRewardsEmitter.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract ExchangeConfig is IExchangeConfig, Ownable
    {
	ISalt public salt;
	IERC20 public wbtc;
	IERC20 public weth;
	IERC20 public usdc;
	IUSDS public usds;

	// The Salty.IO DAO
	// The DAO can only be set once
	IDAO public dao;

	// The rewards emitters
	IRewardsEmitter public stakingRewardsEmitter;
	IRewardsEmitter public liquidityRewardsEmitter;
	IRewardsEmitter public collateralRewardsEmitter;


	// The contract that determines where or not a given wallet is given access to the exchange.
	// Defaults to a simple AccessManager in which a user has access if their country is not only the DAO-controlled list of excluded countries.
	// Note that this could be replaced by alternate AccessManager such as Polygon ID (if the DAO decided that they wanted to do so).
	// Restricts users swaps, liquidity providing, staking and DAO voting - but always allows existing assets to be removed (in case a user is restricted after depositing assets)
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


	function setCollateralRewardsEmitter( IRewardsEmitter _rewardsEmitter ) public onlyOwner
		{
		require( address(_rewardsEmitter) != address(0), "_rewardsEmitter cannot be address(0)" );

		collateralRewardsEmitter = _rewardsEmitter;
		}


	// Provide access to the protocol components that require it and then look to the AccessManager to determine if a wallet should have access.
	function walletHasAccess( address wallet ) public view returns (bool)
		{
		// These protocol components will need access to the exchange contracts
		if ( wallet == address(dao) )
			return true;

		return accessManager.walletHasAccess( wallet );
		}
    }