// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../dao/interfaces/IDAO.sol";
import "../interfaces/IAccessManager.sol";
import "../stable/interfaces/IUSDS.sol";
import "../interfaces/ISalt.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/interfaces/ISaltRewards.sol";

interface IExchangeConfig
	{
	function setDAO( IDAO _dao ) external; // onlyOwner
	function setAccessManager( IAccessManager _accessManager ) external; // onlyOwner
	function setStakingRewardsEmitter( IRewardsEmitter _rewardsEmitter ) external; // onlyOwner
	function setLiquidityRewardsEmitter( IRewardsEmitter _rewardsEmitter ) external; // onlyOwner

	// Views
	function salt() external view returns (ISalt);
	function wbtc() external view returns (IERC20);
	function weth() external view returns (IERC20);
	function usdc() external view returns (IERC20);
	function usds() external view returns (IUSDS);

	function accessManager() external view returns (IAccessManager);
	function dao() external view returns (IDAO);
	function stakingRewardsEmitter() external view returns (IRewardsEmitter);
	function liquidityRewardsEmitter() external view returns (IRewardsEmitter);

	function walletHasAccess( address wallet ) external view returns (bool);
	}
