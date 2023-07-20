// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./openzeppelin/security/ReentrancyGuard.sol";
import "./interfaces/IAAA.sol";
import "./rewards/interfaces/IRewardsEmitter.sol";
import "./dao/interfaces/IDAO.sol";
import "./interfaces/IExchangeConfig.sol";
import "./openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./Upkeepable.sol";


contract AAA is IAAA, ReentrancyGuard, Upkeepable
    {
	using SafeERC20 for IERC20;

    IDAO immutable public dao;
    IPools immutable public pools;
    IExchangeConfig immutable public exchangeConfig;

    IRewardsEmitter immutable public liquidityRewardsEmitter;
	IRewardsEmitter immutable public stakingRewardsEmitter;
	IRewardsEmitter immutable public collateralRewardsEmitter;

	IERC20 immutable public weth;


    constructor( IDAO _dao, IPools _pools, IExchangeConfig _exchangeConfig )
    	{
		require( address(_dao) != address(0), "_dao cannot be address(0)" );
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		dao = _dao;
		pools = _pools;
		exchangeConfig = _exchangeConfig;

		liquidityRewardsEmitter = exchangeConfig.liquidityRewardsEmitter();
		stakingRewardsEmitter = exchangeConfig.stakingRewardsEmitter();
		collateralRewardsEmitter = exchangeConfig.collateralRewardsEmitter();

		weth = exchangeConfig.weth();
    	}


	// Deposits the current WETH balance into the Pools contract for later gas efficient trading.
	// This WETH would have been deposited into this contract from the InitialSale or from a previously used AAA contract.
	function depositOwnedWETH() public nonReentrant
		{
		uint256 wethBalance = weth.balanceOf( address(this) );

		if ( wethBalance > 0 )
			pools.deposit( weth, wethBalance );
		}


	// Checks to see if this contract is not the specified AAA in exchangeConfig and if not sends its WETH to the specified AAA
	function transferAssetsIfReplaced() public nonReentrant
		{
		// Check if this contract has been replaced
		if ( address(exchangeConfig.aaa()) != address(this) )
			{
			// Withdraw WETH from the Pools contract
			uint256 wethBalance = pools.getUserDeposit( address(this), weth );
			pools.withdraw( weth, wethBalance );

			// Send the withdrawn WETH to the new AAA
			weth.safeTransfer( address(exchangeConfig.aaa()), wethBalance );
			}
		}


	// Attempt arbitrage just after the given token swap
	function attemptArbitrage( address swapper, IERC20[] memory swapPath, uint256 amountIn ) public nonReentrant
    	{
    	// Make sure the swap is profitable
    	}


	function _performUpkeep() internal override
		{
		}
	}

