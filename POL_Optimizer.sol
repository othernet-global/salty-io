//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "./openzeppelin/token/ERC20/IERC20.sol";
//import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
//import "./uniswap/core/interfaces/IUniswapV2Pair.sol";
//import "./uniswap/core/interfaces/IUniswapV2Factory.sol";
//import "./uniswap/periphery/interfaces/IUniswapV2Router02.sol";
//import "./rewards/RewardsEmitter.sol";
//import "./staking/interfaces/IStakingConfig.sol";
//import "./interfaces/IExchangeConfig.sol";
//import "./Upkeepable.sol";
//import "./interfaces/IPOL_Optimizer.sol";
//
//
//// @title POL_Optimizer
//// @notice Stores WETH from profits and excess collateral liquidation and forms
//// Protocol Owned Liquidity where the POL that is actually formed is that which
//// has the highest current rewards per liquidity at the time when performUpkeep() is called.
//contract POL_Optimizer is IPOL_Optimizer, ReentrancyGuard, Upkeepable
//    {
//	using SafeERC20 for IERC20;
//
//	// For these values to be changed a new POL_Optimizer contract needs to be set in ExchangeConfig.sol
//	uint256 public constant MINIMUM_TIME_SINCE_LAST_SWAP = 60; // seconds
//	uint256 public constant MAX_SWAP_PERCENT = 25;
//
//    IERC20 public weth;
//    IStakingConfig public stakingConfig;
//    IExchangeConfig public exchangeConfig;
//    IRewardsEmitter public liquidityRewardsEmitter;
//    IUniswapV2Factory public factory;
//    IUniswapV2Router02 public router;
//
//
//    constructor( IStakingConfig _stakingConfig, IExchangeConfig _exchangeConfig, IRewardsEmitter _liquidityRewardsEmitter, IUniswapV2Factory _factory, IUniswapV2Router02 _router )
//    	{
//		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );
//		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
//		require( address(_liquidityRewardsEmitter) != address(0), "_liquidityRewardsEmitter cannot be address(0)" );
//		require( address(_factory) != address(0), "_factory cannot be address(0)" );
//		require( address(_router) != address(0), "_router cannot be address(0)" );
//
//        weth = IERC20(_exchangeConfig.weth());
//		stakingConfig = _stakingConfig;
//		exchangeConfig = _exchangeConfig;
//		liquidityRewardsEmitter = _liquidityRewardsEmitter;
//		factory = _factory;
//        router = _router;
//
//        weth.approve( address(router), type(uint256).max );
//    	}
//
//
//	function _maxOfThree(uint32 a, uint32 b, uint32 c) internal pure returns (uint32)
//		{
//		uint32 maxAB = a > b ? a : b;
//		return maxAB > c ? maxAB : c;
//		}
//
//
//	// The last timestamp in which WETH/tokenA, WETH/tokenB or tokenA/tokenB was swapped
//	function lastSwapTimestamp( address token0, address token1 ) public view returns (uint32)
//		{
//		uint32 blockTimestamp0;
//        uint32 blockTimestamp1;
//        uint32 blockTimestamp01;
//
//		// Evaluate how long it has been since any of the pools involved in forming LP have been used
//		// for swapping as a means to help prevent sandwich attacks on the LP formation.
//
//		// If one of the specified tokens is not WETH, then don't bother checking token0/WETH and token1/WETH timestamps
//		if ( address(token0) != address(weth) )
//		if ( address(token1) != address(weth) )
//			{
//			IUniswapV2Pair pair0 = IUniswapV2Pair( factory.getPair( address(weth), token0 ) );
//			IUniswapV2Pair pair1 = IUniswapV2Pair( factory.getPair( address(weth), token1 ) );
//
//		    require( address(pair0) != address(0), "Nonexistant pair" );
//		    require( address(pair1) != address(0), "Nonexistant pair" );
//
//	        ( , , blockTimestamp0 ) = pair0.getReserves();
//    	    ( , , blockTimestamp1 ) = pair1.getReserves();
//			}
//
//	    IUniswapV2Pair pair01 = IUniswapV2Pair( factory.getPair( token0, token1 ) );
//	    require( address(pair01) != address(0), "Nonexistant pair" );
//
//        ( , , blockTimestamp01 ) = pair01.getReserves();
//
//		// Determine which modification was the most recent
//		return _maxOfThree( blockTimestamp0, blockTimestamp1, blockTimestamp01 );
//		}
//
//
//    // @dev Swaps WETH in the contract for the currently most profitable Salty.IO liquidity
//	function _performUpkeep() internal override
//		{
//		uint256 wethBalance = weth.balanceOf( address( this ) );
//		if ( wethBalance == 0 )
//			return;
//
//		(uint256 maxRewardsPerShare, IUniswapV2Pair bestPool) = findBestPool();
//		if ( maxRewardsPerShare == 0 )
//			return;
//
//		address token0 = bestPool.token0();
//        address token1 = bestPool.token1();
//
//		uint32 lastUpdatedTimestamp = lastSwapTimestamp( token0, token1 );
//
//		uint32 blockTimestamp = uint32(block.timestamp % 2**32);
//		uint32 elapsed = blockTimestamp - lastUpdatedTimestamp;
//
//		// At least one minute since the last swap on the most recent pool to help avoid sandwich attacks
//		// on the swaps from WETH to token0 and token1
//		if ( elapsed < MINIMUM_TIME_SINCE_LAST_SWAP )
//			return;
//
//		// Use a percent of the WETH balance based on how many minutes have elapsed since the last
//		// swap that occurred on any of the pools involved in forming LP.
//		// Each minute elapsed will be one percent of the WETH balance (with a max of 25%).
//		// This is done to prevent the efficacy of front running the optimization.
//		uint256 percent = elapsed / 60;
//
//		if ( percent > MAX_SWAP_PERCENT )
//			percent = MAX_SWAP_PERCENT;
//
//		uint256 wethToUse = ( wethBalance * percent ) / 100;
//
//		// Swap WETH for the tokens in the bestPool (which currently has the most pendingRewards)
//		// Every token on Salty.IO is paired with both WETH and WBTC so each token/WETH pair will exist to make the needed swaps
//        address[] memory path = new address[](2);
//        path[0] = address(weth);
//        if ( address(token0) != address(weth) ) // don't swap from weth to itself
//        	{
//	        path[1] = token0;
//	        router.swapExactTokensForTokens( wethToUse / 2, 0, path, address(this), block.timestamp );
//
//			// Make sure the token is approved as it will need to be used in the router for addLiquidity
//	        (IERC20(token0)).approve( address(router), type(uint256).max );
//	        }
//
//        if ( address(token1) != address(weth) ) // don't swap from weth to itself
//        	{
//	    	path[1] = token1;
//            router.swapExactTokensForTokens( wethToUse / 2, 0, path, address(this), block.timestamp );
//
//			// Make sure the token is approve as it will need to be used in the router for addLiquidity
//	        (IERC20(token1)).approve( address(router), type(uint256).max );
//	        }
//
//		// Form the LP
//		uint256 balance0 = ( IERC20(token0) ).balanceOf( address(this) );
//        uint256 balance1 = ( IERC20(token1) ).balanceOf( address(this) );
//
//		uint256 formedLP;
//		router.addLiquidity( token0, token1, balance0, balance1, 0, 0, address(this), block.timestamp );
//
//		// Send all LP to the DAO
//		IUniswapV2Pair lp = IUniswapV2Pair( factory.getPair( token0, token1 ) );
//
//		uint256 lpBalance = lp.balanceOf(address(this));
//		( IERC20( address(lp) ) ).safeTransfer( address(exchangeConfig.dao()), lpBalance );
//		}
//
//
//	// === VIEWS ===
//
//	// The bestPool is the one that has the highest ratio of pending rewards / staked liquidity in the pool
//	// @param maxRewardsPerShare Returns the max rewards per share for the bestPool (in ether)
//	function findBestPool() public view returns (uint256 maxRewardsPerShare, IUniswapV2Pair bestPool)
//		{
//		IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//		uint256[] memory pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(pools);
//		uint256[] memory sharesPerPool = liquidityRewardsEmitter.sharedRewards().totalSharesForPools(pools);
//
//		maxRewardsPerShare = 0;
//		bestPool = IUniswapV2Pair(address(0));
//
//		for (uint256 i = 0; i < pools.length; i++)
//			{
//			// Make sure there are at least some rewards for the pool in question
//			if ( pendingRewards[i] > 0 )
//				{
//				// Default to uint256.max in case of zero shares for the pool
//				uint256 rewardsPerShare = type(uint256).max;
//
//				if ( sharesPerPool[i] > 0 )
//					rewardsPerShare = ( pendingRewards[i] * 10 ** 18 ) / sharesPerPool[i];
//
//				if (rewardsPerShare > maxRewardsPerShare)
//					{
//					maxRewardsPerShare = rewardsPerShare;
//					bestPool = pools[i];
//					}
//				}
//			}
//		}
//	}