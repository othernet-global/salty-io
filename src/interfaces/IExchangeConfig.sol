// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "../staking/interfaces/ILiquidity.sol";
import "../launch/interfaces/IInitialDistribution.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/interfaces/ISaltRewards.sol";
import "../rewards/interfaces/IEmissions.sol";
import "../interfaces/IAccessManager.sol";
import "../launch/interfaces/IAirdrop.sol";
import "../dao/interfaces/IDAO.sol";
import "../interfaces/ISalt.sol";
import "./IUpkeep.sol";


interface IExchangeConfig
	{
	function setContracts( IDAO _dao, IUpkeep _upkeep, IInitialDistribution _initialDistribution, VestingWallet _teamVestingWallet, VestingWallet _daoVestingWallet ) external; // onlyOwner
	function setAccessManager( IAccessManager _accessManager ) external; // onlyOwner

	// Views
	function salt() external view returns (ISalt);
	function wbtc() external view returns (IERC20);
	function weth() external view returns (IERC20);
	function usdc() external view returns (IERC20);
	function usdt() external view returns (IERC20);

	function daoVestingWallet() external view returns (VestingWallet);
    function teamVestingWallet() external view returns (VestingWallet);
    function initialDistribution() external view returns (IInitialDistribution);

	function accessManager() external view returns (IAccessManager);
	function dao() external view returns (IDAO);
	function upkeep() external view returns (IUpkeep);
	function teamWallet() external view returns (address);

	function walletHasAccess( address wallet ) external view returns (bool);
	}
