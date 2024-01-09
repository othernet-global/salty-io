// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../rewards/interfaces/IRewardsConfig.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "../staking/interfaces/IStakingConfig.sol";
import "../stable/interfaces/IStableConfig.sol";
import "../pools/interfaces/IPools.sol";
import "../interfaces/ISalt.sol";
import "../interfaces/IExchangeConfig.sol";
import "../pools/PoolUtils.sol";
import "../pools/PoolMath.sol";
import "../price_feed/interfaces/IPriceAggregator.sol";


// Efficiency functions called from the Web3 UI to prevent multiple calls on the RPC server

contract Utils
    {
	function tokenNames( address[] memory tokens ) public view returns (string[] memory)
		{
		string[] memory names = new string[]( tokens.length );

		for( uint256 i = 0; i < tokens.length; i++ )
			{
			ERC20 token = ERC20( tokens[i] );

			names[i] = token.symbol();
			}

		return names;
		}


	function tokenDecimals( address[] memory tokens ) public view returns (uint256[] memory)
		{
		uint256[] memory decimals = new uint256[]( tokens.length );

		for( uint256 i = 0; i < tokens.length; i++ )
			{
			ERC20 token = ERC20( tokens[i] );

			decimals[i] = token.decimals();
			}

		return decimals;
		}


	function tokenSupplies( address[] memory tokens ) public view returns (uint256[] memory)
		{
		uint256[] memory supplies = new uint256[]( tokens.length );

		for( uint256 i = 0; i < tokens.length; i++ )
			{
			IERC20 pair = IERC20( tokens[i] );

			supplies[i] = pair.totalSupply();
			}

		return supplies;
		}


	function underlyingTokens( IPoolsConfig poolsConfig, bytes32[] memory poolIDs ) public view returns (address[] memory)
		{
		address[] memory tokens = new address[]( poolIDs.length * 2 );

		uint256 index;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			(IERC20 token0, IERC20 token1) = poolsConfig.underlyingTokenPair( poolIDs[i] );

			tokens[ index++ ] = address(token0);
			tokens[ index++ ] = address(token1);
			}

		return tokens;
		}


	function poolReserves( IPools pools, IPoolsConfig poolsConfig, bytes32[] memory poolIDs ) public view returns (uint256[] memory)
		{
		uint256[] memory reserves = new uint256[]( poolIDs.length * 2 );

		uint256 index;
		for( uint256 i = 0; i < poolIDs.length; i++ )
			{
			(IERC20 token0, IERC20 token1) = poolsConfig.underlyingTokenPair( poolIDs[i] );
			(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves( token0, token1 );

			reserves[ index++ ] = reserve0;
			reserves[ index++ ] = reserve1;
			}

		return reserves;
		}



	function userBalances( address wallet, address[] memory tokenIDs ) public view returns (uint256[] memory)
		{
		uint256[] memory balances = new uint256[]( tokenIDs.length );

		for( uint256 i = 0; i < tokenIDs.length; i++ )
			{
			IERC20 token = IERC20( tokenIDs[i] );

			balances[i] = token.balanceOf( wallet );
			}

		return balances;
		}


	// The current circulating supply of SALT
	function circulatingSALT( IERC20 salt, address emissions, address daoVestingWallet, address teamVestingWallet, address stakingRewardsEmitter, address liquidityRewardsEmitter ) public view returns (uint256)
		{
		// Don't include balances that still haven't been distributed
		return salt.totalSupply() - salt.balanceOf(emissions) - salt.balanceOf(daoVestingWallet) - salt.balanceOf(teamVestingWallet) - salt.balanceOf(stakingRewardsEmitter) - salt.balanceOf(liquidityRewardsEmitter);
		}


	// Shortcut for returning the current percentStakedTimes1000 and stakingAPRTimes1000
	function stakingPercentAndAPR(ISalt salt, IStaking staking, IRewardsConfig rewardsConfig, address stakingRewardsEmitter, address liquidityRewardsEmitter, address emissions, address daoVestingWallet, address teamVestingWallet) public view returns (uint256 percentStakedTimes1000, uint256 stakingAPRTimes1000)
		{
		// Make sure that the InitDistribution has already happened
		if ( salt.balanceOf(stakingRewardsEmitter) == 0 )
			return (0, 0);

		uint256 totalCirculating = circulatingSALT(salt, emissions, daoVestingWallet, teamVestingWallet, stakingRewardsEmitter, liquidityRewardsEmitter);

		uint256 totalStaked = staking.totalShares(PoolUtils.STAKED_SALT);
		if ( totalStaked == 0 )
			return (0, 0);

		percentStakedTimes1000 = ( totalStaked * 100 * 1000 ) / totalCirculating;

		uint256 rewardsEmitterBalance = salt.balanceOf(stakingRewardsEmitter);
		uint256 rewardsEmitterDailyPercentTimes1000 = rewardsConfig.rewardsEmitterDailyPercentTimes1000();

		uint256 yearlyStakingRewardsTimes100000 = ( rewardsEmitterBalance * rewardsEmitterDailyPercentTimes1000 * 365 );// / ( 100 * 1000 );

		stakingAPRTimes1000 = yearlyStakingRewardsTimes100000 / totalStaked;
		}


	function poolID(IERC20 tokenA, IERC20 tokenB) public pure returns (bytes32 _poolID)
		{
		return PoolUtils._poolID(tokenA, tokenB);
		}


	function stakingInfo(IStakingConfig stakingConfig) public view returns (uint256 minUnstakePercent, uint256 minUnstakeWeeks, uint256 maxUnstakeWeeks )
		{
		minUnstakePercent = stakingConfig.minUnstakePercent();
		minUnstakeWeeks = stakingConfig.minUnstakeWeeks();
		maxUnstakeWeeks = stakingConfig.maxUnstakeWeeks();
		}


	// Returns prices with 18 decimals
	function corePrices(IPools pools, IExchangeConfig exchangeConfig, IPriceAggregator priceAggregator) public view returns (uint256 btcPrice, uint256 ethPrice, uint256 saltPrice, uint256 usdsPrice)
		{
		btcPrice =  priceAggregator.getPriceBTC();
		ethPrice =  priceAggregator.getPriceETH();

		IERC20 wbtc = exchangeConfig.wbtc();
		IERC20 weth = exchangeConfig.weth();
		ISalt salt = exchangeConfig.salt();
		IUSDS usds = exchangeConfig.usds();

		// Use SALT/WBTC and SALT/WETH as the basis for the SALT price
		(uint256 reservesA1, uint256 reservesB1) = pools.getPoolReserves(salt, wbtc);
		(uint256 reservesA2, uint256 reservesB2) = pools.getPoolReserves(salt, weth);

		if ( reservesA1 > PoolUtils.DUST )
		if ( reservesA2 > PoolUtils.DUST )
			{
			// Bitcoin reserves have 8 decimals so convert to 18 decimals
			uint256 price1 = reservesB1 * btcPrice * 10**10 / reservesA1;
			uint256 price2 = reservesB2 * ethPrice / reservesA2;

			// Price proportional to the reserves of each pool
			saltPrice = ( price1 * reservesA1 + price2 * reservesA2 ) / ( reservesA1 + reservesA2 );
			}

		// Use WBTC/USDS and WETH/USDS as the basis for the USDS price
		(reservesA1, reservesB1) = pools.getPoolReserves(usds, wbtc);
		(reservesA2, reservesB2) = pools.getPoolReserves(usds, weth);

		if ( reservesA1 > PoolUtils.DUST )
		if ( reservesA2 > PoolUtils.DUST )
			{
			// Bitcoin reserves have 8 decimals so convert to 18 decimals
			uint256 price1 = reservesB1 * btcPrice * 10**10 / reservesA1;
			uint256 price2 = reservesB2 * ethPrice / reservesA2;

			// Price proportional to the reserves of each pool
			usdsPrice = ( price1 * reservesA1 + price2 * reservesA2 ) / ( reservesA1 + reservesA2 );
			}
		}


	function nonUserPoolInfo(ICollateralAndLiquidity collateralAndLiquidity, IRewardsEmitter liquidityRewardsEmitter, IPools pools, IPoolsConfig poolsConfig, IRewardsConfig rewardsConfig, bytes32[] memory poolIDs) public view returns ( address[] memory tokens, string[] memory names, uint256[] memory decimals, uint256[] memory reserves, uint256[] memory totalShares, uint256[] memory pendingRewards, uint256 rewardsEmitterDailyPercentTimes1000 )
		{
		tokens = underlyingTokens(poolsConfig, poolIDs);
		names = tokenNames(tokens);
		decimals = tokenDecimals(tokens);
		reserves = poolReserves(pools, poolsConfig, poolIDs);
		totalShares = collateralAndLiquidity.totalSharesForPools(poolIDs);
		pendingRewards = liquidityRewardsEmitter.pendingRewardsForPools(poolIDs);
		rewardsEmitterDailyPercentTimes1000 = rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		}


	function userPoolInfo(address wallet, ICollateralAndLiquidity collateralAndLiquidity, bytes32[] memory poolIDs, address[] memory tokens) public view returns ( uint256[] memory userCooldowns, uint256[] memory userPoolShares, uint256[] memory userRewardsForPools, uint256[] memory userTokenBalances )
		{
		userCooldowns = collateralAndLiquidity.userCooldowns( wallet, poolIDs );
		userPoolShares = collateralAndLiquidity.userShareForPools( wallet, poolIDs );
   		userRewardsForPools = collateralAndLiquidity.userRewardsForPools( wallet, poolIDs );
		userTokenBalances = userBalances( wallet, tokens );
		}


	function currentTimestamp() public view returns (uint256 timestamp)
		{
		return block.timestamp;
		}


	function userStakingInfo(address wallet, ISalt salt, IStaking staking) public view returns ( uint256 allowance, uint256 saltBalance, uint256 xsaltBalance, uint256 pendingRewards )
		{
		allowance = salt.allowance( wallet, address(staking) );
		saltBalance = salt.balanceOf( wallet );
		xsaltBalance = staking.userXSalt( wallet );

		bytes32[] memory poolIDs = new bytes32[](1);
		poolIDs[0] = PoolUtils.STAKED_SALT;

		pendingRewards = staking.userRewardsForPools( wallet, poolIDs )[0];
		}


	function determineZapSwapAmount( uint256 reserveA, uint256 reserveB, uint256 zapAmountA, uint256 zapAmountB ) external pure returns (uint256 swapAmountA, uint256 swapAmountB )
		{
		return PoolMath._determineZapSwapAmount( reserveA, reserveB, zapAmountA, zapAmountB );
		}


	// Determine the expected swap result for a given series of swaps and amountIn
	function quoteAmountOut( IPools pools, IERC20[] memory tokens, uint256 amountIn ) external view returns (uint256 amountOut)
		{
		require( tokens.length >= 2, "Must have at least two tokens swapped" );

		IERC20 tokenIn = tokens[0];
		IERC20 tokenOut;

		for( uint256 i = 1; i < tokens.length; i++ )
			{
			tokenOut = tokens[i];

			(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(tokenIn, tokenOut);

			if ( reserve0 <= PoolUtils.DUST || reserve1 <= PoolUtils.DUST || amountIn <= PoolUtils.DUST )
				return 0;

			uint256 k = reserve0 * reserve1;

			// Determine amountOut based on amountIn and the reserves
			reserve0 += amountIn;
			amountOut = reserve1 - k / reserve0;

			tokenIn = tokenOut;
			amountIn = amountOut;
			}

		return amountOut;
		}


	// For a given desired amountOut and a series of swaps, determine the amountIn that would be required.
	// amountIn is rounded up
	function quoteAmountIn(  IPools pools, IERC20[] memory tokens, uint256 amountOut ) external view returns (uint256 amountIn)
		{
		require( tokens.length >= 2, "Must have at least two tokens swapped" );

		IERC20 tokenOut = tokens[ tokens.length - 1 ];
		IERC20 tokenIn;

		for( uint256 i = 2; i <= tokens.length; i++ )
			{
			tokenIn = tokens[ tokens.length - i];

			(uint256 reserve0, uint256 reserve1) = pools.getPoolReserves(tokenIn, tokenOut);

			if ( reserve0 <= PoolUtils.DUST || reserve1 <= PoolUtils.DUST || amountOut >= reserve1 || amountOut < PoolUtils.DUST)
				return 0;

			uint256 k = reserve0 * reserve1;

			// Determine amountIn based on amountOut and the reserves
			// Round up here to err on the side of caution
			amountIn = Math.ceilDiv( k, reserve1 - amountOut ) - reserve0;

			tokenOut = tokenIn;
			amountOut = amountIn;
			}

		return amountIn;
		}


	function estimateAddedLiquidity( uint256 reservesA, uint256 reservesB, uint256 maxAmountA, uint256 maxAmountB, uint256 totalLiquidity ) external pure returns (uint256 addedLiquidity)
		{
		// If either reserve is less than dust then consider the pool to be empty and that the added liquidity will become the initial token ratio
		if ( ( reservesA < PoolUtils.DUST ) || ( reservesB < PoolUtils.DUST ) )
			return maxAmountA + maxAmountB;

		// Add liquidity to the pool proportional to the current existing token reserves in the pool.
		// First, try the proportional amount of tokenB for the given maxAmountA
		uint256 proportionalB = ( reservesB * maxAmountA ) / reservesA;

		uint256 addedAmountA;
		uint256 addedAmountB;

		// proportionalB too large for the specified maxAmountB?
		if ( proportionalB > maxAmountB )
			{
			// Use maxAmountB and a proportional amount for tokenA instead
			addedAmountA = ( reservesA * maxAmountB ) / reservesB;
			addedAmountB = maxAmountB;
			}
		else
			{
			addedAmountA = maxAmountA;
			addedAmountB = proportionalB;
			}

		// Determine the amount of liquidity that will be given to the user to reflect their share of the total collateralAndLiquidity.
		if ( addedAmountA > addedAmountB)
			addedLiquidity = (totalLiquidity * addedAmountA) / reservesA;
		else
			addedLiquidity = (totalLiquidity * addedAmountB) / reservesB;
		}


	function stableNonUserData( IStableConfig stableConfig, IStakingConfig stakingConfig, IERC20 usds ) external view returns (uint256 minimumCollateralRatioPercent, uint256 modificationCooldown, uint256 big_minimumCollateralValueForBorrowing, uint256 big_usdsSupply )
		{
		minimumCollateralRatioPercent = stableConfig.minimumCollateralRatioPercent();
		modificationCooldown = stakingConfig.modificationCooldown();
		big_minimumCollateralValueForBorrowing = stableConfig.minimumCollateralValueForBorrowing();
		big_usdsSupply = usds.totalSupply();
		}


	function stableUserData( ICollateralAndLiquidity collateralAndLiquidity, address wallet) external view returns (uint256 big_maxBorrowableUSDS, uint256 big_borrowedUSDS, uint256 big_maxWithdrawableCollateral)
		{
		big_maxBorrowableUSDS = collateralAndLiquidity.maxBorrowableUSDS(wallet);
		big_borrowedUSDS = collateralAndLiquidity.usdsBorrowedByUsers(wallet);
		big_maxWithdrawableCollateral = collateralAndLiquidity.maxWithdrawableCollateral(wallet);
		}



	function statsData(ISalt salt, address emissions, address daoVestingWallet, address teamVestingWallet, address stakingRewardsEmitter, address liquidityRewardsEmitter, IStaking staking, IRewardsConfig rewardsConfig, IUSDS usds ) external view returns ( uint256 saltSupply, uint256 stakedSALT, uint256 burnedSALT, uint256 liquidityRewardsSalt, uint256 rewardsEmitterDailyPercentTimes1000, uint256 usdsSupply )
		{
		saltSupply = circulatingSALT(salt, emissions, daoVestingWallet, teamVestingWallet, stakingRewardsEmitter, liquidityRewardsEmitter);
		stakedSALT = staking.totalShares(PoolUtils.STAKED_SALT );
		burnedSALT = salt.totalBurned();
		liquidityRewardsSalt = salt.balanceOf( liquidityRewardsEmitter );
		rewardsEmitterDailyPercentTimes1000 = rewardsConfig.rewardsEmitterDailyPercentTimes1000();
		usdsSupply = usds.totalSupply();
		}
	}

