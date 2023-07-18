// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./IAAA.sol";
import "../dao/interfaces/IDAO.sol";
import "../interfaces/IAccessManager.sol";
import "../stable/interfaces/IUSDS.sol";
import "../interfaces/ISalt.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/interfaces/IRewardsConfig.sol";

interface IExchangeConfig
	{
	function setDAO( IDAO _dao ) external; // onlyOwner
	function setAAA( IAAA _aaa ) external; // onlyOwner
	function setAccessManager( IAccessManager _accessManager ) external; // onlyOwner
	function setStakingRewardsEmitter( IRewardsEmitter _rewardsEmitter ) external; // onlyOwner
	function setLiquidityRewardsEmitter( IRewardsEmitter _rewardsEmitter ) external; // onlyOwner
	function setCollateralRewardsEmitter( IRewardsEmitter _rewardsEmitter ) external; // onlyOwner

	// Views
	function salt() external view returns (ISalt);
	function wbtc() external view returns (IERC20);
	function weth() external view returns (IERC20);
	function usdc() external view returns (IERC20);
	function usds() external view returns (IUSDS);

	function aaa() external view returns (IAAA);
	function accessManager() external view returns (IAccessManager);
	function dao() external view returns (IDAO);
	function stakingRewardsEmitter() external view returns (IRewardsEmitter);
	function liquidityRewardsEmitter() external view returns (IRewardsEmitter);
	function collateralRewardsEmitter() external view returns (IRewardsEmitter);

	function walletHasAccess( address wallet ) external view returns (bool);
	}
