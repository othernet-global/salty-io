// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.0;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";
import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
import "./IStakingConfig.sol";
import "./SharedRewards.sol";

/**

@title Liquidity
@notice Allows users to stake LP tokens in a Uniswap pool to receive a share of the rewards
*/
contract Liquidity is SharedRewards
    {
	using SafeERC20 for IERC20;

	/**
	 * @dev Event emitted when a user stakes LP
	 * @param wallet Address of the user's wallet.
	 * @param poolID The corresponding pool
	 * @param amount Amount of LP being staked
	 */
     event eStakeLP(
        address indexed wallet,
        IUniswapV2Pair poolID,
        uint256 amount );

	/**
	 * @dev Event emitted when a user unstakes LP
	 * @param wallet Address of the user's wallet.
	 * @param poolID The corresponding pool
	 * @param amount Amount of LP being unstaked
	 */
     event eUnstakeLP(
        address indexed wallet,
        IUniswapV2Pair poolID,
        uint256 amount );


	/**
	 * @dev Constructor for Staking contract
	 * @param _stakingConfig Interface for Staking configuration
	 */
	constructor( IStakingConfig _stakingConfig )
		SharedRewards( _stakingConfig )
		{
		}


    /**
     * @dev Function for staking LP tokens for rewards
     * @param poolID UniswapV2Pair contract address
     * @param amountStaked Amount of tokens to be staked
     */
     function stake( IUniswapV2Pair poolID, uint256 amountStaked ) public nonReentrant
		{
		// Don't allow calling with poolID 0
		require( poolID != STAKED_SALT, "Cannot stake on poolID 0" );

		// Update the user's share of the rewards for the pool
   		_increaseUserShare( msg.sender, poolID, amountStaked, true );

		// The Uniswap LP token address is the poolID
		IERC20 erc20 = IERC20( address(poolID) );

		// Make sure there is no fee while transferring the token to this contract
		uint256 beforeBalance = erc20.balanceOf( address(this) );
		erc20.safeTransferFrom(msg.sender, address(this), amountStaked );
		uint256 afterBalance = erc20.balanceOf( address(this) );

		require( afterBalance == ( beforeBalance + amountStaked ), "Cannot stake tokens with a fee on transfer" );

		emit eStakeLP( msg.sender, poolID, amountStaked );
		}


    /**
     * @dev Function for unstaking LP tokens and claiming any pending rewards
     * @param poolID UniswapV2Pair contract address
     * @param amountUnstaked Amount of tokens to be unstaked
     */
     function unstakeAndClaim( IUniswapV2Pair poolID, uint256 amountUnstaked ) public nonReentrant
		{
		// Don't allow calling with poolID 0
		require( poolID != STAKED_SALT, "Cannot call on poolID 0" );

		// Make sure that the DAO isn't trying to remove liquidity
		require( msg.sender != stakingConfig.saltyDAO(), "DAO cannot unstake LP" );

		// Update the user's share of the rewards for the pool
		// Balance checks are done here
		_decreaseUserShare( msg.sender, poolID, amountUnstaked, true );

		// The Uniswap LP token address is the poolID
		IERC20 erc20 = IERC20( address(poolID) );

		// Transfer the withdrawn token to the caller
		erc20.safeTransfer( msg.sender, amountUnstaked );

		emit eUnstakeLP( msg.sender, poolID, amountUnstaked );
		}
	}