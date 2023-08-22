// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../dao/interfaces/IDAO.sol";
import "../interfaces/IAccessManager.sol";
import "../stable/interfaces/IUSDS.sol";
import "../interfaces/ISalt.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/interfaces/ISaltRewards.sol";
import "../rewards/interfaces/IEmissions.sol";
import "./IUpkeep.sol";


interface IExchangeConfig
	{
	function setDAO( IDAO _dao ) external; // onlyOwner
	function setUpkeep( IUpkeep _upkeep ) external; // onlyOwner
	function setAccessManager( IAccessManager _accessManager ) external; // onlyOwner
	function setStakingRewardsEmitter( IRewardsEmitter _rewardsEmitter ) external; // onlyOwner
	function setLiquidityRewardsEmitter( IRewardsEmitter _rewardsEmitter ) external; // onlyOwner

	function setTeamWallet( address _teamWallet ) external;
	function setVestingWallets( address _teamVestingWallet, address _daoVestingWallet ) external;

	// Views
	function salt() external view returns (ISalt);
	function wbtc() external view returns (IERC20);
	function weth() external view returns (IERC20);
	function dai() external view returns (IERC20);
	function usds() external view returns (IUSDS);

	function teamWallet() external view returns (address);
	function daoVestingWallet() external view returns (address);
    function teamVestingWallet() external view returns (address);

	function accessManager() external view returns (IAccessManager);
	function dao() external view returns (IDAO);
	function upkeep() external view returns (IUpkeep);
	function stakingRewardsEmitter() external view returns (IRewardsEmitter);
	function liquidityRewardsEmitter() external view returns (IRewardsEmitter);

	function walletHasAccess( address wallet ) external view returns (bool);
	}
