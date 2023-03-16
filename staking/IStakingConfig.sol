// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "./IStaking.sol";


interface IStakingConfig
    {
    function salt() external view returns (IERC20);

    function MAXIMUM_WHITELISTED_POOLS() external view returns (uint256);
    function saltyPOL() external view returns (address);
    function pendingSaltyPOL() external view returns (address);
    function pendingSaltyTimestamp() external view returns (uint256);

    function earlyUnstake() external view returns (address);
    function minUnstakePercent() external view returns (uint256);
    function minUnstakeWeeks() external view returns (uint256);
    function maxUnstakeWeeks() external view returns (uint256);

    function depositWithdrawalCooldown() external view returns (uint256);
    function xsaltIsTransferable() external view returns (bool);


	function setXSALTIsTransferable( bool _transferable ) external;
	function initChangeSaltyPOL( address _saltyPOL ) external;
	function confirmChangeSaltyPOL() external;
	function setEarlyUnstake( address _earlyUnstake ) external;
	function whitelist( address poolID ) external;
	function blacklist( address poolID ) external;
	function setUnstakeParams( uint256 _minUnstakeWeeks, uint256 _maxUnstakeWeeks, uint256 _minUnstakePercent ) external;
	function setDepositWithdrawalCooldown( uint256 _depositWithdrawalCooldown ) external;

	function isValidPool( address poolID ) external view returns (bool);
	function whitelistedPools() external view returns (address[] memory);
    }