// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../uniswap/core/interfaces/IUniswapV2Pair.sol";


/**
* @dev Struct containing parameters for calculating the amount of SALT claimable upon completion of an unstake request.
* @param minUnstakeWeeks The minimum number of weeks that an unstake request must be pending before completion.
* @param maxUnstakeWeeks The maximum number of weeks that an unstake request can be pending before completion.
* @param minUnstakePercent The minimum percentage of the original xSALT stake that can be claimed upon completion of an unstake request.
*/
struct UnstakeParams
	{
	uint256 minUnstakeWeeks;  // minUnstakePercent returned here
	uint256 maxUnstakeWeeks; // 100% returned here
	uint256 minUnstakePercent;
	}


interface IStakingConfig
    {
    function MAXIMUM_WHITELISTED_POOLS() external view returns (uint256);

    function salt() external view returns (IERC20);
    function saltyDAO() external view returns (address);

    function earlyUnstake() external view returns (address);
    function unstakeParams() external view returns (UnstakeParams memory);
    function maxUnstakeWeeks() external view returns (uint256);
    function minUnstakePercent() external view returns (uint256);
    function modificationCooldown() external view returns (uint256);

	function setEarlyUnstake( address _earlyUnstake ) external;
	function whitelist( IUniswapV2Pair poolID ) external;
	function unwhitelist( IUniswapV2Pair poolID ) external;
	function setUnstakeParams( uint256 _minUnstakeWeeks, uint256 _maxUnstakeWeeks, uint256 _minUnstakePercent ) external;
	function setModificationCooldown( uint256 _cooldown ) external;

	function isValidPool( IUniswapV2Pair poolID ) external view returns (bool);
	function whitelistedPools() external view returns (IUniswapV2Pair[] memory);
	}