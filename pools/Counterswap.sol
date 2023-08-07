// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IPools.sol";
import "../interfaces/IExchangeConfig.sol";
import "../abdk/ABDKMathQuad.sol";
import "./interfaces/ICounterswap.sol";


// Keeps track of which trades the exchange itself would like to make and allows a counter swap to be performed immediately after a user swap.
// The counter swaps are done at market rate and only when the rates are favorable compared against the 30 minute EMA (to avoid sandwich attacks and manipulated prices).
// They essentially return the reserves to the state they were before the user swap and are used to gradually swap WETH arbitrage profits to SALT for distribution, WETH to WBTC and USDS for protocol owned liquidity and WBTC and WETH to USDS for liquidated collateral.

contract Counterswap is ICounterswap
	{
	using SafeERC20 for IERC20;

   	IPools immutable public pools;
	IExchangeConfig immutable public exchangeConfig;

	IERC20 immutable public usds;
	IDAO immutable public dao;

	bytes16 public immutable ZERO = ABDKMathQuad.fromUInt(0);

	// The amount of tokens that have been deposited for counter swapping
	mapping(IERC20=>mapping(IERC20=>uint256)) private _depositedTokens;  // [depositedToken][desiredToken]


	constructor( IPools _pools, IExchangeConfig _exchangeConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;

		// Cached for efficiency
		usds = exchangeConfig.usds();
		dao = exchangeConfig.dao();
		}


	// Transfer a specified token from the caller to this swap buffer and then deposit it into the Pools contract.
	function depositToken( IERC20 tokenToDeposit, IERC20 desiredToken, uint256 amountToDeposit ) public
		{
		require( (msg.sender == address(dao)) || (msg.sender == address(usds)), "Deposit only callable from the DAO or USDS contracts" );

		// Transfer from the caller
		tokenToDeposit.safeTransferFrom( msg.sender, address(this), amountToDeposit );

		// Deposit to the Pools contract
		tokenToDeposit.approve( address(pools), amountToDeposit );
		pools.deposit(tokenToDeposit, amountToDeposit);

		// Keep track of the deposited tokens
		_depositedTokens[tokenToDeposit][desiredToken] += amountToDeposit;
		}


	// Withdraw a specified token that is deposited in the Pools contract and send it to the caller.
	// This is used to withdraw the converted tokens that were deposited in the above function.
	function withdrawToken( IERC20 tokenToWithdraw, uint256 amountToWithdraw ) public
		{
		require( (msg.sender == address(dao)) || (msg.sender == address(usds)), "Withdraw only callable from the DAO or USDS contracts" );

		pools.withdraw( tokenToWithdraw, amountToWithdraw );
		tokenToWithdraw.safeTransfer( msg.sender, amountToWithdraw );
		}


	// Given that the user just swapped swapTokenIn->swapTokenOut, check to see if the protocol should counter swap (in exactly the opposite direction)
	// and that the rate is reasonable compared to the 30 minute EMA of the reserves between the two tokens.
	function shouldCounterswap( IERC20 swapTokenIn, IERC20 swapTokenOut, uint256 swapAmountIn, uint256 swapAmountOut ) public returns (bool _shouldCounterswap)
		{
		require( msg.sender == address(pools), "Only callable from the Pools contract" );

		// Make sure at least the swapAmountOut of swapTokenOut has been deposited (as it will need to be swapped for swapTokenIn)
		uint256 amountDeposited = _depositedTokens[swapTokenOut][swapTokenIn];
		if ( amountDeposited < swapAmountOut )
			return false;

		// We'll be checking the averageRatio of reserveIn / reserveOut to see if the current opportunity to counterswap is more profitable than at the average ratio
		bytes16 averageRatio = pools.averageReserveRatio(swapTokenIn, swapTokenOut);
		if ( ABDKMathQuad.eq( averageRatio, ZERO ) )
			return false;

		// Calculate the ratio of swapAmountIn to swapAmountOut from the user's swap that they just made.
		bytes16 swapRatio = ABDKMathQuad.div(ABDKMathQuad.fromUInt(swapAmountIn), ABDKMathQuad.fromUInt(swapAmountOut));

		// We want the buffer to get a reasonable amount of swapTokenIn compared to the swapTokenOut that it will need to provide the user with.
		// So we want the swapRatio of swapAmountIn/swapAmountOut to be greater than the recent averageRatio.
		if (ABDKMathQuad.cmp(swapRatio, averageRatio) < 0)
			return false;

		// Reduce the deposited amount of swapTokenOut for swapTokenIn as the counterswap will take place (in Pools after seeing this function return true)
		_depositedTokens[swapTokenOut][swapTokenIn] -= swapAmountOut;

		return true;
		}


	// === VIEWS ===
	function depositedTokens( IERC20 depositedToken, IERC20 desiredToken ) public view returns (uint256)
		{
		return _depositedTokens[depositedToken][desiredToken];
		}
	}