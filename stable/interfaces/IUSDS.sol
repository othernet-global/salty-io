// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../openzeppelin/token/ERC20/IERC20.sol";
import "./ICollateral.sol";
import "../../pools/interfaces/IPools.sol";
import "../../dao/interfaces/IDAO.sol";


interface IUSDS is IERC20
	{
	function setContracts( ICollateral _collateral, IPools _pools, IDAO _dao ) external;

	function mintTo( address wallet, uint256 amount ) external;
	function shouldBurnMoreUSDS( uint256 usdsToBurn ) external;
	function performUpkeep() external;
	}

