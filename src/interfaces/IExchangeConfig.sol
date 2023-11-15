// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "../stable/interfaces/ICollateralAndLiquidity.sol";
import "../launch/interfaces/IInitialDistribution.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/interfaces/ISaltRewards.sol";
import "../rewards/interfaces/IEmissions.sol";
import "../interfaces/IAccessManager.sol";
import "../launch/interfaces/IAirdrop.sol";
import "../stable/interfaces/IUSDS.sol";
import "../dao/interfaces/IDAO.sol";
import "../interfaces/ISalt.sol";
import "./IUpkeep.sol";
import "./IManagedWallet.sol";


interface IExchangeConfig
	{
	function setContracts( IDAO _dao, IUpkeep _upkeep, IInitialDistribution _initialDistribution, IAirdrop _airdrop, VestingWallet _teamVestingWallet, VestingWallet _daoVestingWallet ) external; // onlyOwner
	function setAccessManager( IAccessManager _accessManager ) external; // onlyOwner

	// Views
	function salt() external view returns (ISalt);
	function wbtc() external view returns (IERC20);
	function weth() external view returns (IERC20);
	function dai() external view returns (IERC20);
	function usds() external view returns (IUSDS);

	function managedTeamWallet() external view returns (IManagedWallet);
	function daoVestingWallet() external view returns (VestingWallet);
    function teamVestingWallet() external view returns (VestingWallet);
    function initialDistribution() external view returns (IInitialDistribution);

	function accessManager() external view returns (IAccessManager);
	function dao() external view returns (IDAO);
	function upkeep() external view returns (IUpkeep);
	function airdrop() external view returns (IAirdrop);

	function walletHasAccess( address wallet ) external view returns (bool);
	}
