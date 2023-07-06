// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./IStakingRewards.sol";


interface ILiquidity is IStakingRewards
	{
	event eStakeLP(address indexed wallet,bytes32 pool,uint256 amount);
	event eUnstakeLP(address indexed wallet,bytes32 pool,uint256 amount);


	function stake( bytes32 pool, uint256 amountStaked ) external;
	function unstakeAndClaim( bytes32 pool, uint256 amountUnstaked ) external;
	}
