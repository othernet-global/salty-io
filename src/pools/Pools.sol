// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPools.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IPoolsConfig.sol";
import "./PoolUtils.sol";
import "./Counterswap.sol";
import "./PoolStats.sol";
import "../arbitrage/ArbitrageSearch.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./PoolMath.sol";


// The Pools contract stores the reserves that are used for swaps within the DEX.
// It handles deposits, arbitrage, and counterswaps for the various whitelisted pools.

// Only the CollateralAndLiquidity.sol contract can add and remove liquidity from the pools (and is as such the only owner of liquidity as far as Pools.sol is concerned).
// CollateralAndLiquidity.sol itself keeps track of which users have deposited liquidity using StakingRewards.userShare (as it derives from Liquidity which derives from StakingRewards).

contract Pools is IPools, ReentrancyGuard, PoolStats, ArbitrageSearch, Ownable
	{
	using SafeERC20 for IERC20;

	struct PoolReserves
		{
		uint112 reserve0;						// The token reserves such that address(token0) < address(token1)
		uint112 reserve1;

		// The last block that the reserves were involved in a swap.
		// Used to prevent same block manipulation of counterswaps and user liquidation.
		uint32 lastSwapBlock;
		}

	IUSDS immutable public usds;
	IDAO public dao;
	ICollateralAndLiquidity public collateralAndLiquidity;

	// Set to true when starting the exchange is approved by the bootstrapBallot
	bool private _startExchangeApproved;

	// Keeps track of the pool reserves by poolID
	mapping(bytes32=>PoolReserves) private _poolReserves;

	// User token balances for deposited tokens
	mapping(address=>mapping(IERC20=>uint256)) private _userDeposits;


	constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig )
	PoolStats(_exchangeConfig, _poolsConfig)
	ArbitrageSearch(_exchangeConfig)
		{
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );

		poolsConfig = _poolsConfig;
		usds = _exchangeConfig.usds();
		}


	function setContracts( IDAO _dao, ICollateralAndLiquidity _collateralAndLiquidity ) public onlyOwner
		{
		require( address(_dao) != address(0), "_dao cannot be address(0)" );
		require( address(_collateralAndLiquidity) != address(0), "_collateralAndLiquidity cannot be address(0)" );

		dao = _dao;
		collateralAndLiquidity = _collateralAndLiquidity;

		// setDAO can only be called once
		renounceOwnership();
		}


	function startExchangeApproved() public
		{
    	require( msg.sender == address(exchangeConfig.initialDistribution().bootstrapBallot()), "Pools.startExchangeApproved can only be called from the BootstrapBallot contract" );

		_startExchangeApproved = true;
		}


	modifier ensureNotExpired(uint deadline)
		{
		require(block.timestamp <= deadline, "TX EXPIRED");
		_;
		}


	// Given two tokens and their maximum amounts for added liquidity, determine which amounts to actually add so that the added token ratio is the same as the existing reserve token ratio.
	// The amounts returned are in reserve token order rather than in call token order.
	// NOTE - this does not stake added collateralAndLiquidity. Liquidity.depositLiquidityAndIncreaseShare() needs to be used instead to add liquidity, stake it and receive added rewards.
	function _addLiquidity( bytes32 poolID, bool flipped, IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 totalLiquidity ) internal returns(uint256 addedAmount0, uint256 addedAmount1, uint256 addedLiquidity)
		{
		// Ensure that tokenA/B and maxAmountA/B are ordered in reserve token order: such that address(tokenA) < address(tokenB)
		if ( flipped )
			{
			(tokenA,tokenB) = (tokenB, tokenA);
			(maxAmountA,maxAmountB) = (maxAmountB, maxAmountA);
			}

		PoolReserves storage reserves = _poolReserves[poolID];
		uint256 reserve0 = reserves.reserve0;
		uint256 reserve1 = reserves.reserve1;

		// If either reserve is less than dust then consider the pool to be empty and that the added liquidity will become the initial token ratio
		if ( ( reserve0 < PoolUtils.DUST ) || ( reserve1 < PoolUtils.DUST ) )
			{
			// Update the reserves
			reserves.reserve0 += uint112(maxAmountA);
			reserves.reserve1 += uint112(maxAmountB);

			return ( maxAmountA, maxAmountB, Math.sqrt(maxAmountA * maxAmountB) );
			}

		// Add liquidity to the pool proportional to the current existing token reserves in the pool.
		// First, try the proportional amount of tokenA for the given maxAmountB
		uint256 proportionalB = ( maxAmountA * reserve1 ) / reserve0;

		// proportionalB too large for the specified maxAmountB?
		if ( proportionalB > maxAmountB )
			{
			// Use maxAmountB and a proportional amount for tokenA instead
			addedAmount0 = ( maxAmountB * reserve0 ) / reserve1;
			addedAmount1 = maxAmountB;
			}
		else
			{
			addedAmount0 = maxAmountA;
			addedAmount1 = proportionalB;
			}

		// Update the reserves
		reserves.reserve0 += uint112(addedAmount0);
		reserves.reserve1 += uint112(addedAmount1);

		// Determine the amount of liquidity that will be given to the user to reflect their share of the total collateralAndLiquidity.
		// Rounded down in favor of the protocol
		addedLiquidity = (addedAmount0 * totalLiquidity) / reserve0;
		}


	// Add liquidity for the specified trading pair (must be whitelisted)
	function addLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, uint256 totalLiquidity ) public returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity)
		{
		require( msg.sender == address(collateralAndLiquidity), "Pools.addLiquidity is only callable from the CollateralAndLiquidity contract" );
		require( _startExchangeApproved, "The exchange is not yet live" );
		require( address(tokenA) != address(tokenB), "Cannot add liquidity for duplicate tokens" );

		require( maxAmountA > PoolUtils.DUST, "The amount of tokenA to add is too small" );
		require( maxAmountB > PoolUtils.DUST, "The amount of tokenB to add is too small" );

		(bytes32 poolID, bool flipped) = PoolUtils._poolID(tokenA, tokenB);

		// Note that addedAmountA and addedAmountB here are in reserve token order and may be flipped from the call token order specified in the arguments.
		(addedAmountA, addedAmountB, addedLiquidity) = _addLiquidity( poolID, flipped, tokenA, tokenB, maxAmountA, maxAmountB, totalLiquidity );

		// Make sure the minimum liquidity has been added
		require( addedLiquidity >= minLiquidityReceived, "Too little liquidity received" );

		// Flip back to call token order so the amounts make sense to the caller?
		if ( flipped )
			(addedAmountA, addedAmountB) = (addedAmountB, addedAmountA);

		// Transfer the tokens from the sender - only tokens without fees should be whitelisted on the DEX
		tokenA.safeTransferFrom(msg.sender, address(this), addedAmountA );
		tokenB.safeTransferFrom(msg.sender, address(this), addedAmountB );
		}


	// Remove liquidity for the user and reclaim the underlying tokens
	function removeLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToRemove, uint256 minReclaimedA, uint256 minReclaimedB, uint256 totalLiquidity ) public nonReentrant returns (uint256 reclaimedA, uint256 reclaimedB)
		{
		require( msg.sender == address(collateralAndLiquidity), "Pools.removeLiquidity is only callable from the CollateralAndLiquidity contract" );
		require( liquidityToRemove > 0, "The amount of liquidityToRemove cannot be zero" );

		(bytes32 poolID, bool flipped) = PoolUtils._poolID(tokenA, tokenB);

		// Determine how much liquidity is being withdrawn and round down in favor of the protocol
		PoolReserves storage reserves = _poolReserves[poolID];
		reclaimedA = ( reserves.reserve0 * liquidityToRemove ) / totalLiquidity;
		reclaimedB = ( reserves.reserve1 * liquidityToRemove ) / totalLiquidity;

		// Make sure that removing liquidity doesn't drive the reserves below DUST
		if ( ( reserves.reserve0 - reclaimedA ) < PoolUtils.DUST )
			reclaimedA = reserves.reserve0 - PoolUtils.DUST;

		if ( ( reserves.reserve1 - reclaimedB ) < PoolUtils.DUST )
			reclaimedB = reserves.reserve1 - PoolUtils.DUST;

		reserves.reserve0 -= uint112(reclaimedA);
		reserves.reserve1 -= uint112(reclaimedB);

		// Switch reclaimed amounts back to the order that was specified in the call arguments so they make sense to the caller
		if (flipped)
			(reclaimedA,reclaimedB) = (reclaimedB,reclaimedA);

		require( reclaimedA >= minReclaimedA, "Insufficient underlying tokens returned" );
		require( reclaimedB >= minReclaimedB, "Insufficient underlying tokens returned" );

		// Send the reclaimed tokens to the user
		tokenA.safeTransfer( msg.sender, reclaimedA );
		tokenB.safeTransfer( msg.sender, reclaimedB );
		}


	// Allow the users to deposit tokens into the contract.
	// Users who swap frequently can keep tokens in the contract in order to reduce gas costs of token transfers in and out of the contract.
	// This is not rewarded or considered staking in any way.  It's simply a way to reduce gas costs by preventing transfers at swap time.
	function deposit( IERC20 token, uint256 amount ) public nonReentrant
		{
        require( amount > PoolUtils.DUST, "Deposit amount too small");

		_userDeposits[msg.sender][token] += amount;

		// Transfer the tokens from the sender - only tokens without fees should be whitelsited on the DEX
		token.safeTransferFrom(msg.sender, address(this), amount );
		}


	// Withdraw tokens that were previously deposited
    function withdraw( IERC20 token, uint256 amount ) public nonReentrant
    	{
    	require( _userDeposits[msg.sender][token] >= amount, "Insufficient balance to withdraw specified amount" );
        require( amount > PoolUtils.DUST, "Withdraw amount too small");

		_userDeposits[msg.sender][token] -= amount;

    	// Send the token to the user
    	token.safeTransfer( msg.sender, amount );
    	}


	// Calculate amountOut based on the current token reserves and the specified amountIn and then update the reserves.
	// Only the reserves are updated - the function does not adjust deposited user balances or do ERC20 transfers.
    function _adjustReservesForSwap( IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn ) internal returns (uint256 amountOut)
    	{
        (bytes32 poolID, bool flipped) = PoolUtils._poolID(tokenIn, tokenOut);

        PoolReserves storage reserves = _poolReserves[poolID];
        uint256 reserve0 = reserves.reserve0;
        uint256 reserve1 = reserves.reserve1;

        require((reserve0 >= PoolUtils.DUST) && (reserve1 >= PoolUtils.DUST), "Insufficient reserves before swap");

        uint256 k = reserve0 * reserve1;

		// See if the reserves are flipped in regards to the argument token order
        if (flipped)
        	{
			reserve1 += amountIn;
			amountOut = reserve0 - k / reserve1;
			reserve0 -= amountOut;
        	}
        else
        	{
			reserve0 += amountIn;
			amountOut = reserve1 - k / reserve0;
			reserve1 -= amountOut;
        	}

		// Make sure that the reserves after swap are above DUST
        require( (reserve0 >= PoolUtils.DUST) && (reserve1 >= PoolUtils.DUST), "Insufficient reserves after swap");

		// Update the reserves
		reserves.reserve0 = uint112(reserve0);
		reserves.reserve1 = uint112(reserve1);

		// Keep track of the swapped block for the poolID
		reserves.lastSwapBlock = uint32(block.number);
    	}


    // Arbitrage a token to itself along a circular path (starting and ending with WETH), taking advantage of imbalances in the exchange pools.
    // Does not require any deposited tokens to make the call, but requires that the resulting amountOut is greater than the specified arbitrageAmountIn.
    // Essentially the caller virtually "borrows" arbitrageAmountIn of the starting token and virtually "repays" it from their received amountOut at the end of the swap chain.
    // The extra amountOut (compared to arbitrageAmountIn) is the arbitrage profit.
	function _arbitrage( bool isWhitelistedPair, IERC20 arbToken2, IERC20 arbToken3, uint256 arbitrageAmountIn ) internal
		{
		uint256 amountOut = _adjustReservesForSwap( weth, arbToken2, arbitrageAmountIn );

		if ( isWhitelistedPair )
			amountOut = _adjustReservesForSwap( arbToken2, arbToken3, amountOut );
		else
			{
			amountOut = _adjustReservesForSwap( arbToken2, wbtc, amountOut );
			amountOut = _adjustReservesForSwap( wbtc, arbToken3, amountOut );
			}

		amountOut = _adjustReservesForSwap( arbToken3, weth, amountOut );

		uint256 arbitrageProfit = amountOut - arbitrageAmountIn;

		// Deposit the arbitrage profit for the DAO - later to be divided between the DAO, SALT stakers and liquidity providers in DAO.performUpkeep
 		_userDeposits[address(dao)][weth] += arbitrageProfit;

		// Update the stats related to the pools that contributed to the arbitrage so they can be rewarded proportionally later
		_updateProfitsFromArbitrage( isWhitelistedPair, arbToken2, arbToken3, arbitrageProfit );
		}


	// Determine an arbitrage path to use for the given swap which just occured in this same transaction
	function _findArbitrageWhitelisted( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountInValueInETH ) internal view returns (IERC20 token2, IERC20 token3, uint256 arbtrageAmountIn)
    	{
		// Whitelisted pairs have a direct pool within the exchange
   		(token2, token3) = _directArbitragePath( swapTokenIn, swapTokenOut );

		// Cache the reserves for efficiency
		// Arbitrage cycle: weth->token2->token3->weth
		(uint256 reservesA0, uint256 reservesA1) = getPoolReserves( weth, token2);
		(uint256 reservesB0, uint256 reservesB1) = getPoolReserves( token2, token3);
		(uint256 reservesC0, uint256 reservesC1) = getPoolReserves( token3, weth);

		// Search for the most profitable arbtrageAmountIn
		return (token2, token3, _binarySearchWhitelisted(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1 ) );
    	}


	// Determine an arbitrage path to use for the swapTokenIn->WETH->swapTokenOut swap which just occured in this same transaction
	function _findArbitrageNonWhitelisted( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountInValueInETH ) internal view returns (IERC20 token2, IERC20 token3, uint256 arbtrageAmountIn)
    	{
		// Nonwhitelisted pairs will use intermediate WETH as: token1->WETH->token2
    	(token2, token3) = _indirectArbitragePath( swapTokenIn, swapTokenOut );

		// Cache the reserves for efficiency
		// Arbitrage cycle: weth->token2->wbtc->token3->weth
		(uint256 reservesA0, uint256 reservesA1) = getPoolReserves( weth, token2);
		(uint256 reservesB0, uint256 reservesB1) = getPoolReserves( token2, wbtc);
		(uint256 reservesC0, uint256 reservesC1) = getPoolReserves( wbtc, token3);
		(uint256 reservesD0, uint256 reservesD1) = getPoolReserves( token3, weth);

		// Search for the most profitable arbtrageAmountIn
		return (token2, token3, _binarySearchNonWhitelisted(swapAmountInValueInETH, reservesA0, reservesA1, reservesB0, reservesB1, reservesC0, reservesC1, reservesD0, reservesD1 ) );
    	}


	// Check to see if profitable arbitrage is possible after the swap that was just made (previously in this same transaction)
	function _attemptArbitrage( bool isWhitelistedPair, IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn ) internal
		{
		uint256 swapAmountInValueInETH;

		// Determine the ETH equivalent of swapAmountIn of swapTokenIn
		if ( address(swapTokenIn) == address(weth) )
			swapAmountInValueInETH = swapAmountIn;
		else
			{
			(uint256 reservesWETH, uint256 reservesTokenIn) = getPoolReserves(weth, swapTokenIn);

			if ( (reservesWETH < PoolUtils.DUST) || (reservesTokenIn < PoolUtils.DUST) )
				return; // can't arbitrage as there are not enough reserves to determine value in ETH

			swapAmountInValueInETH = ( swapAmountIn * reservesWETH ) / reservesTokenIn;
			}

		if ( swapAmountInValueInETH <= PoolUtils.DUST )
			return;

		// Determine the best arbitragePath (if any) with the arbitrage cycle starting and ending with WETH.
		IERC20 arbToken2;
		IERC20 arbToken3;
		uint256 arbitrageAmountIn;

		if ( isWhitelistedPair )
			(arbToken2, arbToken3, arbitrageAmountIn) = _findArbitrageWhitelisted(swapTokenIn, swapTokenOut, swapAmountInValueInETH);
		else
			(arbToken2, arbToken3, arbitrageAmountIn) =_findArbitrageNonWhitelisted(swapTokenIn, swapTokenOut, swapAmountInValueInETH);

		// If arbitrage is viable, then perform it
		if (arbitrageAmountIn > 0)
			_arbitrage(isWhitelistedPair, arbToken2, arbToken3, arbitrageAmountIn);
		}


	// Adjust the reserves for swapping between the two specified tokens and then immediately attempt arbitrage.
	// Perform a counterswap if possible - essentially undoing the original swap by restoring the reserves to their preswap state.
	// Does not require exchange access for the sending wallet.
	function _adjustReservesAndAttemptArbitrage( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, bool isWhitelistedPair ) internal returns (uint256 swapAmountOut)
		{
		if ( isWhitelistedPair )
			{
			bytes32 poolID = PoolUtils._poolIDOnly(swapTokenIn, swapTokenOut);

			// For counterswapping, make sure a swap hasn't already been placed within this block (which could indicate attempted manipulation)
			// Check this before _adjustReservesForSwap is called as it will change lastSwapBlock for the poolID
			bool counterswapDisabled = ( _poolReserves[poolID].lastSwapBlock == uint32(block.number) );

			// Direct swap between the two tokens as they have a pool
			swapAmountOut = _adjustReservesForSwap( swapTokenIn, swapTokenOut, swapAmountIn );

			// Make sure the swap meets the specified minimums
			require( swapAmountOut >= minAmountOut, "Insufficient resulting token amount" );

			// We'll be trying to to counterswap in the opposite direction of the user's swap
			address counterswapAddress = Counterswap._determineCounterswapAddress(swapTokenOut, swapTokenIn, wbtc, weth, salt, usds);

			// Check if a counterswap should be performed (for when the protocol itself wants to gradually swap some tokens at a reasonable price)
			// Make sure a swap hasn't been made within the same block and the counterswap deposit exists
			if ( ( ! counterswapDisabled ) && ( _counterswapDepositExists( counterswapAddress, swapTokenOut, swapAmountOut ) ) )
				{
				// Perform the counterswap (in the opposite direction of the user's swap)
				_adjustReservesForSwap( swapTokenOut, swapTokenIn, swapAmountOut );

				// Adjust the Counterswap contract's token deposits: from performing the swapTokenOut->swapTokenIn counterswap.
				// This essentially returns the reserves to what they were before the user's swap.
				// Counterswap deposits are actually owned by the Pools contract - as the Pools contract is derived from the Counterswap contract.
				_userDeposits[counterswapAddress][swapTokenOut] -= swapAmountOut;
				_userDeposits[counterswapAddress][swapTokenIn] += swapAmountIn;

				// No arbitrage or updating pool stats with counterswap
				return swapAmountOut;
				}
			}
		else
			{
			// Swap with WETH as the intermediate between swapTokenIn and swapTokenOut (as every token is pooled with WETH)
			uint256 wethOut = _adjustReservesForSwap( swapTokenIn, weth, swapAmountIn );
			swapAmountOut = _adjustReservesForSwap( weth, swapTokenOut, wethOut );

			// Make sure the swap meets the specified minimums
			require( swapAmountOut >= minAmountOut, "Insufficient resulting token amount" );
			}

		// The user's swap has just been made - attempt atomic arbitrage to rebalance the pool and yield arbitrage profit
		_attemptArbitrage( isWhitelistedPair, swapTokenIn, swapTokenOut, swapAmountIn );
		}


    // Swap one token for another.
    // Uses the direct pool between two tokens if available, or if not uses token1->WETH->token2 (as every token on the DEX is pooled with both WETH and WBTC)
    // Having simpler swaps without multiple tokens in the swap chain makes it simpler (and less expensive gas wise) to find suitable arbitrage opportunities.
    // Cheap arbitrage gas-wise is important as arbitrage will be atomically attempted with every swap transaction.

    // Requires that the first token in the chain has already been deposited for the caller.
    // Does not require exchange access on the contract level - as other contracts using the swap feature may not have the ability to grant themselves access.
	// Regional restrictions on swapping within the browser itself may be added by the DAO.
	function swap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline, bool isWhitelistedPair ) public nonReentrant ensureNotExpired(deadline) returns (uint256 swapAmountOut)
		{
		// Confirm and adjust user deposits
		mapping(IERC20=>uint256) storage userDeposits = _userDeposits[msg.sender];

    	require( userDeposits[swapTokenIn] >= swapAmountIn, "Insufficient deposited token balance of initial token" );
		userDeposits[swapTokenIn] -= swapAmountIn;

		swapAmountOut = _adjustReservesAndAttemptArbitrage(swapTokenIn, swapTokenOut, swapAmountIn, minAmountOut, isWhitelistedPair );

		// Deposit the final tokenOut for the caller
		userDeposits[swapTokenOut] += swapAmountOut;
		}


	// Convenience method that allows the sender to deposit tokenIn, swap to tokenOut and then have tokenOut sent to the sender
    // Does not require exchange access on the contract level - as other contracts using the swap feature may not have the ability to grant themselves access.
	// Regional restrictions on swapping within the browser itself may be added by the DAO.
	function depositSwapWithdraw(IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline, bool isWhitelistedPair ) public nonReentrant ensureNotExpired(deadline) returns (uint256 swapAmountOut)
		{
		// Transfer the tokens from the sender - only tokens without fees should be whitelsited on the DEX
		swapTokenIn.safeTransferFrom(msg.sender, address(this), swapAmountIn );

		swapAmountOut = _adjustReservesAndAttemptArbitrage(swapTokenIn, swapTokenOut, swapAmountIn, minAmountOut, isWhitelistedPair );

    	// Send tokenOut to the user
    	swapTokenOut.safeTransfer( msg.sender, swapAmountOut );
		}


	// === COUNTERSWAPS ===

	// Check to see if counterswap has been deposited to swap in the opposite direction of a swap a user just made
	function _counterswapDepositExists( address counterswapAddress, IERC20 swapTokenOut, uint256 swapAmountOut ) internal view returns (bool shouldCounterswap)
		{
		// Make sure at least the swapAmountOut of swapTokenOut has been deposited (as it will need to be swapped for the user's swapTokenIn)
		return _userDeposits[counterswapAddress][swapTokenOut] >= swapAmountOut;
		}


	// Transfer a specified token from the caller to this swap buffer and then deposit it into the Pools contract.
	function depositTokenForCounterswap( address counterswapAddress, IERC20 tokenToDeposit, uint256 amountToDeposit ) public
		{
		require( (msg.sender == address(exchangeConfig.upkeep())) || (msg.sender == address(usds)), "Pools.depositTokenForCounterswap is only callable from the Upkeep or USDS contracts" );

		// Transfer from the caller
		tokenToDeposit.safeTransferFrom( msg.sender, address(this), amountToDeposit );

		// Credit the counterswapAddress
		_userDeposits[counterswapAddress][tokenToDeposit] += amountToDeposit;
		}


	// Withdraw a specified token that is deposited in the Pools contract and send it to the caller.
	// This is to withdraw the resulting tokens resulting from counterswaps.
	function withdrawTokenFromCounterswap( address counterswapAddress, IERC20 tokenToWithdraw, uint256 amountToWithdraw ) public
		{
		require( (msg.sender == address(exchangeConfig.upkeep())) || (msg.sender == address(usds)), "Pools.withdrawTokenFromCounterswap is only callable from the Upkeep or USDS contracts" );

		// Debit the counterswapAddress
		_userDeposits[counterswapAddress][tokenToWithdraw] -= amountToWithdraw;

    	// Send the token to the caller
    	tokenToWithdraw.safeTransfer( msg.sender, amountToWithdraw );
		}


	// === VIEWS ===

	function lastSwapBlock( bytes32 poolID ) public view returns (uint256 _lastSwapBlock)
		{
		return _poolReserves[poolID].lastSwapBlock;
		}


	// The pool reserves for two specified tokens.
	// The reserves are returned in the order specified by the token arguments - which may not be the address(tokenA) < address(tokenB) order stored in the PoolInfo struct itself.
	function getPoolReserves(IERC20 tokenA, IERC20 tokenB) public view returns (uint256 reserveA, uint256 reserveB)
		{
		(bytes32 poolID, bool flipped) = PoolUtils._poolID(tokenA, tokenB);
		PoolReserves memory reserves = _poolReserves[poolID];
		reserveA = reserves.reserve0;
		reserveB = reserves.reserve1;

		// Return the reserves in the order that they were requested
		if (flipped)
			(reserveA, reserveB) = (reserveB, reserveA);
		}


	// A user's deposited balance for a token
	function depositedUserBalance(address user, IERC20 token) public view returns (uint256)
		{
		return _userDeposits[user][token];
		}
	}