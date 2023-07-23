// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.20;

import "../openzeppelin/security/ReentrancyGuard.sol";
import "../openzeppelin/token/ERC20/ERC20.sol";
import "./interfaces/IPools.sol";
import "../openzeppelin/utils/math/Math.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IPoolsConfig.sol";
import "./PoolUtils.sol";
import "./PoolMath.sol";
import "../arbitrage/ArbitrageProfits.sol";


contract Pools is IPools, ReentrancyGuard, ArbitrageProfits
	{
	struct PoolReserves
		{
		uint256 reserve0;					// The token reserves such that address(token0) < address(token1)
		uint256 reserve1;
		}

	event eLiquidityAdded(address indexed user, bytes32 indexed poolID, uint256 addedLiquidity);
	event eLiquidityRemoved(address indexed user, bytes32 indexed poolID, uint256 removedLiquidity);
	event eTokensDeposited(address indexed user, IERC20 indexed token, uint256 amount);
	event eTokensWithdrawn(address indexed user, IERC20 indexed token, uint256 amount);
	event eZapInLiquidity(address indexed user, IERC20 indexed tokenIn, IERC20 indexed tokenOut, uint256 zapAmountIn, uint256 zapAmountOut);

	// Unused for gas efficiency - saves 2.5k gas for each hop in the swap chain. As swaps include 3-4 hop arbitrage this becomes signifcant exceeding 10% of the transaction gas cost.
	// event eTokensSwapped(address indexed user, IERC20 indexed tokenIn, IERC20 indexed tokenOut, uint256 amountIn, uint256 amountOut);

	using SafeERC20 for IERC20;


	IExchangeConfig immutable public exchangeConfig;
	IPoolsConfig immutable public poolsConfig;
	IDAO public dao;

	// Cached for efficiency
	IERC20 public weth;

	// Token balances less than dust are treated as if they don't exist at all.
	// With the 18 decimals that are used for most tokens, DUST has a value of 0.0000000000000001
	// For tokens with 6 decimal places (like USDC) DUST has a value of .0001
	uint256 constant public DUST = 100;

	// Keeps track of the pool reserves by poolID
	mapping(bytes32=>PoolReserves) private _poolReserves;

	// The total liquidity for each poolID
	mapping(bytes32=>uint256) public totalLiquidity;

	// User token balances for deposited tokens
	mapping(address=>mapping(IERC20=>uint256)) private _userDeposits;

	// Keep track of the amount of liquidity owned by users for each poolID
	mapping(address=>mapping(bytes32=>uint256)) private _userLiquidity;



	constructor( IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig )
		{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );

		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;

		weth = exchangeConfig.weth();
		}


	function setDAO( IDAO _dao ) public
		{
		require( address(dao) == address(0), "setDAO can only be called once" );
		require( address(_dao) != address(0), "_dao cannot be address(0)" );

		dao = _dao;
		}


	modifier ensureNotExpired(uint deadline)
		{
		require(block.timestamp <= deadline, "TX EXPIRED");
		_;
		}


	// Given two tokens and their maximum amounts for added liquidity, determine which amounts to actually add so that the added token ratio is the same as the existing reserve token ratio.
	// The amounts returned are in reserve token order rather than in call token order
	function _determineAmountsToAdd( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB ) internal view returns(bytes32 poolID, bool flipped, uint256 addedAmount0, uint256 addedAmount1, uint256 addedLiquidity)
		{
		// Ensure that tokenA/B and maxAmountA/B are ordered in reserve token order: such that address(tokenA) < address(tokenB)
		(poolID, flipped) = PoolUtils.poolID(tokenA, tokenB);

		if ( flipped )
			{
			(tokenA,tokenB) = (tokenB, tokenA);
			(maxAmountA,maxAmountB) = (maxAmountB, maxAmountA);
			}

		// Determine the current pool reserves
		(uint256 reserve0, uint256 reserve1) = getPoolReserves( tokenA, tokenB );

		// If either reserve is less than dust then consider the pool to be empty and that the added liquidity will become the initial token ratio
		if ( ( reserve0 <= DUST ) || ( reserve1 <= DUST ) )
			return ( poolID, flipped, maxAmountA, maxAmountB, Math.sqrt(maxAmountA * maxAmountB) );

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

		// Determine the amount of liquidity that will be given to the user to reflect their share of the total liquidity.
		// Rounded down in favor of the protocol
		addedLiquidity = (addedAmount0 * totalLiquidity[poolID]) / reserve0;
		}


    // Transfer an ERC20 token from the sender to this contract, but revert if the token has a fee on transfer
    function _transferFromUserNoFeeOnTransfer( IERC20 token, uint256 amount ) internal
    	{
		// Make sure there is no fee while transferring the token to this contract
		uint256 beforeBalance = token.balanceOf( address(this) );

		// User allowance and balance not checked to save gas - safeTransferFrom will revert if either is lacking
		token.safeTransferFrom(msg.sender, address(this), amount );

		uint256 afterBalance = token.balanceOf( address(this) );
		require( afterBalance == ( beforeBalance + amount ), "Cannot deposit tokens with a fee on transfer" );
    	}


	// Add liquidity for the specified trading pair (must be whitelisted)
	function addLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 maxAmountA, uint256 maxAmountB, uint256 minLiquidityReceived, uint256 deadline ) public nonReentrant ensureNotExpired(deadline) returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity)
		{
		require( address(tokenA) != address(tokenB), "Cannot add liquidity for duplicate tokens" );

		require( maxAmountA > DUST, "The amount of tokenA to add is too small" );
		require( maxAmountB > DUST, "The amount of tokenB to add is too small" );

		bytes32 poolID;
		bool flipped;

		// Note that addedAmountA and addedAmountB here are in reserve token order and may be flipped from the call token order specified in the arguments.
		(poolID, flipped, addedAmountA, addedAmountB, addedLiquidity) = _determineAmountsToAdd( tokenA, tokenB, maxAmountA, maxAmountB );

		// Make sure the minimum liquidity has been added
		require( addedLiquidity >= minLiquidityReceived, "Too little liquidity received" );

		// Update the reserves
		_poolReserves[poolID].reserve0 += addedAmountA;
		_poolReserves[poolID].reserve1 += addedAmountB;

		// Update the liquidity totals for the user and protocol
		_userLiquidity[msg.sender][poolID] += addedLiquidity;
		totalLiquidity[poolID] += addedLiquidity;

		// Flip back to call token order so the amounts make sense to the caller?
		if ( flipped )
			(addedAmountA, addedAmountB) = (addedAmountB, addedAmountA);

		// Transfer the tokens from the sender
		_transferFromUserNoFeeOnTransfer( tokenA, addedAmountA );
		_transferFromUserNoFeeOnTransfer( tokenB, addedAmountB );

		emit eLiquidityAdded(msg.sender, poolID, addedLiquidity);
		}


	// Remove liquidity for the user and reclaim the underlying tokens
	function removeLiquidity( IERC20 tokenA, IERC20 tokenB, uint256 liquidityToRemove, uint256 minReclaimedA, uint256 minReclaimedB, uint256 deadline ) public nonReentrant ensureNotExpired(deadline) returns (uint256 reclaimedA, uint256 reclaimedB)
		{
		require( liquidityToRemove > 0, "The amount of liquidityToRemove cannot be zero" );

		(bytes32 poolID, bool flipped) = PoolUtils.poolID(tokenA, tokenB);

		PoolReserves storage reserves = _poolReserves[poolID];

		uint256 _totalLiquidity = totalLiquidity[poolID];
		require( _userLiquidity[msg.sender][poolID] >= liquidityToRemove, "Cannot remove more liquidity than the current balance" );

		// Determine what the withdrawn liquidity is worth and round down in favor of the protocol
		reclaimedA = ( reserves.reserve0 * liquidityToRemove ) / _totalLiquidity;
		reclaimedB = ( reserves.reserve1 * liquidityToRemove ) / _totalLiquidity;

		reserves.reserve0 -= reclaimedA;
		reserves.reserve1 -= reclaimedB;

		_userLiquidity[msg.sender][poolID] -= liquidityToRemove;
        totalLiquidity[poolID] = _totalLiquidity - liquidityToRemove;

		// Switch reclaimed amounts back to the order that was specified in the call arguments so they make sense to the caller
		if (flipped)
			(reclaimedA,reclaimedB) = (reclaimedB,reclaimedA);

		require( reclaimedA >= minReclaimedA, "Insufficient underlying tokens returned" );
		require( reclaimedB >= minReclaimedB, "Insufficient underlying tokens returned" );

		// Send the reclaimed tokens to the user
		tokenA.safeTransfer( msg.sender, reclaimedA );
		tokenB.safeTransfer( msg.sender, reclaimedB );

		emit eLiquidityRemoved(msg.sender, poolID, liquidityToRemove);
		}


	// Allow the users to deposit tokens into the contract.
	// Users who swap frequently can keep tokens in the contract in order to reduce gas costs of token transfers in and out of the contract.
	// This is not rewarded or considered staking in any way.  It's simply a way to reduce gas costs by preventing transfers at swap time.
	function deposit( IERC20 token, uint256 amount ) public nonReentrant
		{
        require( amount > DUST, "Deposit amount too small");

		_userDeposits[msg.sender][token] += amount;

		// Transfer the tokens from the sender
		_transferFromUserNoFeeOnTransfer( token, amount );

		emit eTokensDeposited(msg.sender, token, amount);
		}


	// Withdraw tokens that were previously deposited
    function withdraw( IERC20 token, uint256 amount ) public nonReentrant
    	{
    	require( _userDeposits[msg.sender][token] >= amount, "Insufficient balance to withdraw specified amount" );
        require( amount > DUST, "Withdraw amount too small");

		_userDeposits[msg.sender][token] -= amount;

    	// Send the token to the user
    	token.safeTransfer( msg.sender, amount );

    	emit eTokensWithdrawn(msg.sender, token, amount);
    	}


	// Internal swap that calculates amountOut based on token reserves and the specified amountIn and then updates the reserves.
	// It only adjusts the reserves - it does not adjust deposited user balances or do ERC20 transfers.
    function _adjustReservesForSwap( IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn ) internal returns (uint256 amountOut, bytes32 poolID)
    	{
    	bool flipped;
        (poolID, flipped) = PoolUtils.poolID(tokenIn, tokenOut);

        PoolReserves storage reserves = _poolReserves[poolID];

        uint256 reserve0 = reserves.reserve0;
        uint256 reserve1 = reserves.reserve1;

		// Flip reserves to the token order in the arguments
        if (flipped)
            (reserve0, reserve1) = (reserve1, reserve0);

        require(reserve0 > DUST, "Insufficient reserve0 for swap");
        require(reserve1 > DUST, "Insufficient reserve1 for swap");

        uint256 k = reserve0 * reserve1;

        // Determine amountOut based on amountIn and the reserves
        reserve0 += amountIn;
        amountOut = reserve1 - k / reserve0;
        reserve1 -= amountOut;

		// Flip back to the reserve token order
        if (flipped)
            (reserve0, reserve1) = (reserve1, reserve0);

        // Update poolInfo
		reserves.reserve0 = reserve0;
		reserves.reserve1 = reserve1;
    	}


    // Arbitrage a token to itself along a circular path (ending with the starting token), taking advantage of imbalances in the exchange pools.
    // Does not require any deposited tokens to make the call, but requires that the resulting amountOut is greater than the specified arbitrageAmountIn.
    // Essentially the caller virtually "borrows" arbitrageAmountIn of the starting token and virtually "repays" it from their received amountOut at the end of the swap chain.
    // The extra amountOut (compared to arbitrageAmountIn) is the arbitrage profit.
	function _arbitrage( IERC20[] memory arbitrageSwapPath, uint256 arbitrageAmountIn ) internal
		{
		uint256 arbitrageSwapPathLength = arbitrageSwapPath.length;

		// Will be used by ArbitrageProfits._updateArbitrageStats to keep track of which pools contributed to the arbitrage (so they can be rewarded proportionally)
		bytes32[] memory arbitragePathPoolIDs = new bytes32[](arbitrageSwapPathLength);

		uint256 amount = arbitrageAmountIn;
		for( uint256 i = 0; i < arbitrageSwapPathLength - 1; i++ )
			( amount, arbitragePathPoolIDs[i]) = _adjustReservesForSwap( arbitrageSwapPath[i], arbitrageSwapPath[i + 1], amount );

		// Complete the cycle
		( amount, arbitragePathPoolIDs[arbitrageSwapPathLength - 1]) = _adjustReservesForSwap( arbitrageSwapPath[arbitrageSwapPathLength - 1], arbitrageSwapPath[0], amount );

		require( amount > arbitrageAmountIn, "With arbitrage, resulting amountOut must be greater than arbitrageAmountIn" );

		uint256 arbitrageProfit = amount - arbitrageAmountIn;

		// ArbitrageProfits will be later divided between the DAO, SALT stakers and liquidity providers in ArbitrageProfits.performUpkeep
 		_userDeposits[address(this)][ arbitrageSwapPath[0] ] += arbitrageProfit;

		// Update the stats related to the pools that contributed to the arbitrage so they can be rewarded proportionally later
		_updateArbitrageStats( arbitragePathPoolIDs, arbitrageProfit );
		}


	// Check to see if profitable arbitrage is possible after the swap that was just made (previously in this same transaction)
	function _attemptArbitrage( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, bool isWhitelistedPair ) internal
		{
		uint256 swapAmountInValueInETH;

		// Determine the ETH equivalent of swapAmountIn of the initial token in the chain
		if ( address(swapTokenIn) == address(weth) )
			swapAmountInValueInETH = swapAmountIn;
		else
			{
			(uint256 reservesWETH, uint256 reservesTokenIn) = getPoolReserves(weth, swapTokenIn);

			if ( (reservesWETH<=DUST) || (reservesTokenIn<=DUST) )
				return; // can't arbitrage as there are not enough reserves to determine value in ETH

			swapAmountInValueInETH = ( swapAmountIn * reservesWETH ) / reservesTokenIn;
			}

		// Determine the best arbitragePath (if any)
   		(IERC20[] memory arbitrageSwapPath, uint256 arbitrageAmountIn) = poolsConfig.arbitrageSearch().findArbitrage(swapTokenIn, swapTokenOut, swapAmountInValueInETH, isWhitelistedPair );

		// If arbitrage is viable, then perform it
		if ( arbitrageAmountIn > 0 )
			_arbitrage( arbitrageSwapPath, arbitrageAmountIn );
		}


	// Adjust the reserves for swapping between the two specified tokens and then immediately attempt arbitrage
	function _adjustReservesAndAttemptArbitrage( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut ) internal returns (uint256 swapAmountOut)
		{
		// See if tokenIn and tokenOut are whitelisted and therefore can have direct liquidity in the pool
		(bytes32 poolID,) = PoolUtils.poolID(swapTokenIn, swapTokenOut);
		bool isWhitelistedPair = poolsConfig.isWhitelisted(poolID);

		if ( isWhitelistedPair )
			{
			// Direct swap between the two tokens
			( swapAmountOut,) = _adjustReservesForSwap( swapTokenIn, swapTokenOut, swapAmountIn );
			}
		else
			{
			// Swap with WETH as the intermediate between swapTokenIn and swapTokenOut (as every token is pooled with WETH)
			( uint256 wethOut,) = _adjustReservesForSwap( swapTokenIn, weth, swapAmountIn );
			( swapAmountOut,) = _adjustReservesForSwap( weth, swapTokenOut, wethOut );
			}

		// Make sure the swap meet's the specified minimums
		require( swapAmountOut >= minAmountOut, "Insufficient resulting token amount" );

		// The user's swap has just been made - attempt atomic arbitrage to rebalance the pool and yield arbitrage profit
		_attemptArbitrage( swapTokenIn, swapTokenOut, swapAmountIn, isWhitelistedPair );
		}


    // Swap one token for another.
    // Uses the direct pool between two tokens if available, or if not uses token1->WETH->token2 (as every token on the DEX is pooled with WETH)
    // Having simpler swaps without multiple tokens in the swap chain makes it simpler (and less expensive gas wise) to find suitable arbitrage opportunities.
    // Cheap arbitrage gas-wise is important as arbitrage will be perform at swap time.
    // Requires that the first token in the chain has already been deposited for msg.sender
	function swap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline ) public nonReentrant ensureNotExpired(deadline) returns (uint256 swapAmountOut)
		{
		// Confirm and adjust user deposits
		mapping(IERC20=>uint256) storage userDeposits = _userDeposits[msg.sender];

    	require( userDeposits[swapTokenIn] >= swapAmountIn, "Insufficient deposited token balance of initial token" );
		userDeposits[swapTokenIn] -= swapAmountIn;

		swapAmountOut = _adjustReservesAndAttemptArbitrage(swapTokenIn, swapTokenOut, swapAmountIn, minAmountOut );

		// Deposit the final tokenOut for the caller
		userDeposits[swapTokenOut] += swapAmountOut;
		}


	// Convenience method that allows the sender to deposit tokenIn, swap to tokenOut and then have tokenOut sent to the sender
	function depositSwapWithdraw(IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 minAmountOut, uint256 deadline) public nonReentrant ensureNotExpired(deadline) returns (uint256 swapAmountOut)
		{
		// Transfer tokenIn from the sender
		_transferFromUserNoFeeOnTransfer( swapTokenIn, swapAmountIn );

		swapAmountOut = _adjustReservesAndAttemptArbitrage(swapTokenIn, swapTokenOut, swapAmountIn, minAmountOut );

    	// Send tokenOut to the user
    	swapTokenOut.safeTransfer( msg.sender, swapAmountOut );
		}


	function _determineZapSwapAmount( IERC20 tokenA, IERC20 tokenB, uint256 zapAmountA, uint256 zapAmountB ) internal view returns (uint256 swapAmountA, uint256 swapAmountB )
		{
		(uint256 reserveA, uint256 reserveB) = getPoolReserves(tokenA, tokenB);
		uint8 decimalsA = ERC20(address(tokenA)).decimals();
		uint8 decimalsB = ERC20(address(tokenB)).decimals();

		// Determine how much of either token needs to be swapped to give them a ratio equivalent to the reserves
		// Placed in intermediate variable due to Foundry coverage glitch: https://github.com/foundry-rs/foundry/issues/4305
		(uint256 swapAmountA2, uint256 swapAmountB2) = PoolMath.determineZapSwapAmount(reserveA, reserveB, zapAmountA, zapAmountB, decimalsA, decimalsB );

		require( swapAmountA2 <= zapAmountA, "swapAmount cannot exceed zapAmount" );
		require( swapAmountB2 <= zapAmountB, "swapAmount cannot exceed zapAmount" );

		return (swapAmountA2, swapAmountB2);
		}


	// Deposit an arbitrary amount of one or both tokens into the pool and receive liquidity corresponding the the value of both of them.
	// As the ratio of tokens added to the pool has to be the same as the existing ratio of reserves, some of the excess token will be swapped to the other.
	// If bypassSwap is true then this functions identically to addLiquidity and no swap is performed first to balance the tokens before the liquidity add.
	// Zapped tokens will be transferred from the sender.
	// Due to preCision reduction during zapping calculation, the minimum possible reserves and quantity possible to zap is .000101,
	function dualZapInLiquidity(IERC20 tokenA, IERC20 tokenB, uint256 zapAmountA, uint256 zapAmountB, uint256 minLiquidityReceived, uint256 deadline, bool bypassSwap ) public returns (uint256 addedAmountA, uint256 addedAmountB, uint256 addedLiquidity)
		{
		if ( ! bypassSwap )
			{
			(uint256 swapAmountA, uint256 swapAmountB ) = _determineZapSwapAmount( tokenA, tokenB, zapAmountA, zapAmountB );

			// tokenA is in excess so swap some of it to tokenB before adding liquidity?
			if ( swapAmountA > 0)
				{
				// Swap from tokenA to tokenB and adjust the zapAmounts
				zapAmountA -= swapAmountA;
				zapAmountB +=  depositSwapWithdraw( tokenA, tokenB, swapAmountA, 0, block.timestamp );
				}

			// tokenB is in excess so swap some of it to tokenA before adding liquidity?
			if ( swapAmountB > 0)
				{
				// Swap from tokenB to tokenA and adjust the zapAmounts
				zapAmountB -= swapAmountB;
				zapAmountA += depositSwapWithdraw( tokenB, tokenA, swapAmountB, 0, block.timestamp );
				}
			}

		emit eZapInLiquidity(msg.sender, tokenA, tokenB, zapAmountA, zapAmountB );

		// Assuming bypassSwap was false, the ratio of both tokens should now be the same as the ratio of the current reserves (within precision).
		// Otherwise it will just be this normal addLiquidity call.
		return addLiquidity(tokenA, tokenB, zapAmountA, zapAmountB, minLiquidityReceived, deadline );
		}


	// ==== VIEWS ====

	// The pool reserves for two specified tokens.
	// The reserves are returned in the order specified by the token arguments - which may not be the address(tokenA) < address(tokenB) order stored in the PoolInfo struct itself.
	function getPoolReserves(IERC20 tokenA, IERC20 tokenB) public view returns (uint256 reserveA, uint256 reserveB)
		{
		(bytes32 poolID, bool flipped) = PoolUtils.poolID(tokenA, tokenB);
		PoolReserves memory reserves = _poolReserves[poolID];
		reserveA = reserves.reserve0;
		reserveB = reserves.reserve1;

		// Return the reserves in the order that they were requested
		if (flipped)
			(reserveA, reserveB) = (reserveB, reserveA);
		}


	// A user's deposited balance for a token
	function depositBalance(address user, IERC20 token) public view returns (uint256)
		{
		return _userDeposits[user][token];
		}


	// A user's liquidity in a pool
	function getUserLiquidity(address user, IERC20 tokenA, IERC20 tokenB) public view returns (uint256)
		{
		(bytes32 poolID,) = PoolUtils.poolID(tokenA, tokenB);
		return _userLiquidity[user][poolID];
		}
	}