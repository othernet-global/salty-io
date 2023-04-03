// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
import "./IStaking.sol";


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
    function depositWithdrawalCooldown() external view returns (uint256);

	function setEarlyUnstake( address _earlyUnstake ) external;
	function whitelist( IUniswapV2Pair poolID ) external;
	function blacklist( IUniswapV2Pair poolID ) external;
	function setUnstakeParams( uint256 _minUnstakeWeeks, uint256 _maxUnstakeWeeks, uint256 _minUnstakePercent ) external;
	function setDepositWithdrawalCooldown( uint256 _depositWithdrawalCooldown ) external;

	function isValidPool( IUniswapV2Pair poolID ) external view returns (bool);
	function whitelistedPools() external view returns (IUniswapV2Pair[] memory);

	function oneWeek() external view returns (uint256);
    }