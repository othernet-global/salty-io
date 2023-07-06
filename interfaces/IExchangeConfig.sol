// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./IAAA.sol";
import "./IPOL_Optimizer.sol";
import "../dao/interfaces/IDAO.sol";
import "../interfaces/IAccessManager.sol";
import "../stable/interfaces/ILiquidator.sol";
import "../interfaces/ISalt.sol";


interface IExchangeConfig
	{
	function setDAO( IDAO _dao ) external; // onlyOwner
	function setAAA( IAAA _aaa ) external; // onlyOwner
	function setLiquidator( ILiquidator _liquidator ) external; // onlyOwner
	function setAccessManager( IAccessManager _accessManager ) external; // onlyOwner
	function setOptimizer( IPOL_Optimizer _optimizer ) external; // onlyOwner

	// Views
	function salt() external view returns (ISalt);
	function wbtc() external view returns (IERC20);
	function weth() external view returns (IERC20);
	function usdc() external view returns (IERC20);
	function usds() external view returns (IERC20);

	function aaa() external view returns (IAAA);
	function accessManager() external view returns (IAccessManager);
	function dao() external view returns (IDAO);
	function optimizer() external view returns (IPOL_Optimizer);
    function liquidator() external view returns (ILiquidator);

	function walletHasAccess( address wallet ) external view returns (bool);
	}
