// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "../../rewards/interfaces/ISaltRewards.sol";
import "../../stable/interfaces/IUSDS.sol";
import "../../pools/interfaces/IPools.sol";
import "../../interfaces/ISalt.sol";

interface IDAO
	{
	function finalizeBallot( uint256 ballotID ) external;

	function withdrawArbitrageProfits( IERC20 weth ) external returns (uint256 withdrawnAmount);
	function formPOL( IERC20 tokenA, IERC20 tokenB, uint256 amountA, uint256 amountB ) external;
	function processRewardsFromPOL() external;
	function withdrawPOL( IERC20 tokenA, IERC20 tokenB, uint256 percentToLiquidate ) external;

	// Views
	function pools() external view returns (IPools);
	function websiteURL() external view returns (string memory);
	function countryIsExcluded( string calldata country ) external view returns (bool);
	}