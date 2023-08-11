// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../../openzeppelin/token/ERC20/IERC20.sol";
import "../../dao/interfaces/IDAO.sol";


interface IPoolStats
	{
	function setDAO( IDAO _dao ) external;
	function clearProfitsForPools( bytes32[] memory poolIDs ) external;

	// Views
	function averageReserveRatio( IERC20 tokenA, IERC20 tokenB ) external returns (bytes16 averageRatio);
	}

