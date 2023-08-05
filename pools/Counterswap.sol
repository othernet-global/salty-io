// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "./interfaces/IPools.sol";
import "../openzeppelin/utils/math/Math.sol";
import "../interfaces/IExchangeConfig.sol";
import "../abdk/ABDKMathQuad.sol";
import "./interfaces/ICounterswap.sol";


// Keeps track of which trades the protocol would like to make and allows a counter swap to be performed after a user swap in order to swap tokens in the desired direction.
// The counter swaps are done at market rate and only when the rates are favorable compared against the 30 minute EMA (to avoid sandwich attacks and manipulated prices).
// They essentially return the reserves to the state they were before the user swap and are used to swap WETH arbitrage profits to SALT for distribution, WETH to WBTC and USDS for protocol owned liquidity and WBTC and WETH to USDS for liquidated collateral.

contract Counterswap is ICounterswap
	{
	// The amount of tokens that have been deposited for counter swapping to other certain tokens.
	mapping(IERC20=>mapping(IERC20=>uint256)) private _depositedTokens;  // [depositedToken][desiredToken]

   	IPools immutable public pools;
	IExchangeConfig immutable public exchangeConfig;

	IERC20 immutable public usds;
	IDAO immutable public dao;

	bytes16 immutable public ZERO;


	constructor( IPools _pools, IExchangeConfig _exchangeConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;

		// Cached for efficiency
		usds = exchangeConfig.usds();
		dao = exchangeConfig.dao();

		ZERO = ABDKMathQuad.fromUInt(0);
		}


	// Transfer a specified token from the caller to this swap buffer and then deposit it into the Pools contract (and have that deposit owned by this contract).
	function depositToken( IERC20 tokenToDeposit, IERC20 desiredToken, uint256 amountToDeposit ) public
		{
		// Only callable from the DAO and the USDS contracts
		require( (msg.sender == address(dao)) || (msg.sender == address(usds)), "Only callable from the DAO or USDS contracts" );

		// Transfer from the caller
		tokenToDeposit.transferFrom( msg.sender, address(this), amountToDeposit );

		// Deposit to the Pools contract
		pools.deposit(tokenToDeposit, amountToDeposit);

		// Update the buffer
		_depositedTokens[tokenToDeposit][desiredToken] += amountToDeposit;
		}


	// Given that the user just swapped swapTokenIn->swapTokenOut, check to see if the protocol should counter swap
	// and that the rate is reasonable compared to the 30 minute EMA of the reserves between the two tokens.
	function shouldCounterswap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 swapAmountOut ) public returns (bool _shouldCounterswap)
		{
		// Make sure at least the swapAmountOut of swapTokenOut has been deposited (as it will need to be swapped for swapTokenIn)
		uint256 amountDeposited = _depositedTokens[swapTokenOut][swapTokenIn];
		if ( amountDeposited < swapAmountOut )
			return false;

		// Check that the price is favorable compared to the 30 minute reserve ratio EMA
		bytes16 averageRatio = pools.averageReserveRatio(swapTokenIn, swapTokenOut);
		if ( ABDKMathQuad.eq( averageRatio, ZERO ) )
			return false;

		// Calculate the ratio of swapAmountIn to swapAmountOut
		bytes16 swapRatio = ABDKMathQuad.div(ABDKMathQuad.fromUInt(swapAmountIn), ABDKMathQuad.fromUInt(swapAmountOut));

		// We want the buffer to get a reasonable amount of swapTokenIn compared to the swapTokenOut that it will need to provide the user with.
		// So we want the swapRatio of swapAmountIn/swapAmountOut to be greater than the recent averageRatio.
		if (ABDKMathQuad.cmp(swapRatio, averageRatio) < 0)
			return false;

		// Update the amount of deposited swapTokenOut waiting to swap for swapTokenIn
		_depositedTokens[swapTokenOut][swapTokenIn] -= swapAmountOut;

		return true;
		}
	}