// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/finance/VestingWallet.sol";
import "./price_feed/interfaces/IPriceAggregator.sol";
import "./stable/interfaces/IStableConfig.sol";
import "./rewards/interfaces/IEmissions.sol";
import "./pools/interfaces/IPoolsConfig.sol";
import "./interfaces/IExchangeConfig.sol";
import "./dao/interfaces/IDAOConfig.sol";
import "./pools/interfaces/IPools.sol";
import "./dao/interfaces/IDAO.sol";


// Performs the following upkeep for each call to performUpkeep():
// (Uses a maximum of 2.3 million gas with 100 whitelisted pools according to UpkeepGasUsage.t.sol)

// 1. Swaps tokens previously sent to the Liquidizer contract for USDS and burns specified amounts of USDS.

// 2. Withdraws existing WETH arbitrage profits from the Pools contract and rewards the caller of performUpkeep() with default 5% of the withdrawn amount.
// 3. Converts a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.
// 4. Converts a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.
// 5. Converts remaining WETH to SALT and sends it to SaltRewards.

// 6. Sends SALT Emissions to the SaltRewards contract.
// 7. Distributes SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
// 8. Distributes SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.

// 9. Collects SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL), sends 10% to the initial dev team and burns a default 50% of the remaining - the rest stays in the DAO.
// 10. Sends SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
// 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).

// WETH arbitrage profits are converted directly via depositSwapWithdraw - as performUpkeep is called often and the generated arbitrage profits should be manageable compared to the size of the reserves.
// Additionally, simulations show that the impact from sandwich attacks on swap transactions (even without specifying slippage) is limited due to the atomic arbitrage process.
// See PoolUtils.__placeInternalSwap and Sandwich.t.sol for more details.

contract Upkeep is IUpkeep, ReentrancyGuard
    {
	using SafeERC20 for ISalt;
	using SafeERC20 for IUSDS;
	using SafeERC20 for IERC20;

    event UpkeepError(string description, bytes error);

	IPools immutable public pools;
	IExchangeConfig  immutable public exchangeConfig;
	IPoolsConfig immutable public poolsConfig;
	IDAOConfig immutable public daoConfig;
	IStableConfig immutable public stableConfig;
	IPriceAggregator immutable public priceAggregator;
	ISaltRewards immutable public saltRewards;
	ICollateralAndLiquidity immutable public collateralAndLiquidity;
	IEmissions immutable public emissions;
	IDAO immutable public dao;

	IERC20  immutable public weth;
	ISalt  immutable public salt;
	IUSDS  immutable public usds;
	IERC20  immutable public dai;

	uint256 public lastUpkeepTimeEmissions;
	uint256 public lastUpkeepTimeRewardsEmitters;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IDAOConfig _daoConfig, IStableConfig _stableConfig, IPriceAggregator _priceAggregator, ISaltRewards _saltRewards, ICollateralAndLiquidity _collateralAndLiquidity, IEmissions _emissions, IDAO _dao )
		{
		pools = _pools;
		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;
		daoConfig = _daoConfig;
		stableConfig = _stableConfig;
		priceAggregator = _priceAggregator;
		saltRewards = _saltRewards;
		collateralAndLiquidity = _collateralAndLiquidity;
		emissions = _emissions;
		dao = _dao;

		// Cached for efficiency
		weth = _exchangeConfig.weth();
		salt = _exchangeConfig.salt();
		usds = _exchangeConfig.usds();
		dai = _exchangeConfig.dai();

		lastUpkeepTimeEmissions = block.timestamp;
		lastUpkeepTimeRewardsEmitters = block.timestamp;

		// Approve for future WETH swaps.
		// This contract only has a temporary WETH balance within the performUpkeep() function itself.
		weth.approve( address(pools), type(uint256).max );
		}


	modifier onlySameContract()
		{
    	require(msg.sender == address(this), "Only callable from within the same contract");
    	_;
		}


	// Note - while the following steps are public so that they can be wrapped in a try/catch, they are all still only callable from this same contract.

	// 1. Swap tokens previously sent to the Liquidizer contract for USDS and burn specified amounts of USDS.
	function step1() public onlySameContract
		{
		collateralAndLiquidity.liquidizer().performUpkeep();
		}


	// 2. Withdraw existing WETH arbitrage profits from the Pools contract and reward the caller of performUpkeep() with default 5% of the withdrawn amount.
	function step2(address receiver) public onlySameContract
		{
		uint256 withdrawnAmount = exchangeConfig.dao().withdrawArbitrageProfits(weth);
		if ( withdrawnAmount == 0 )
			return;

		// Default 5% of the arbitrage profits for the caller of performUpkeep()
		uint256 rewardAmount = withdrawnAmount * daoConfig.upkeepRewardPercent() / 100;

		// Send the reward
		weth.safeTransfer(receiver, rewardAmount);
		}


	// Have the DAO form the specified Protocol Owned Liquidity with the given amount of WETH
	function _formPOL( IERC20 tokenA, IERC20 tokenB, uint256 amountWETH) internal
		{
		uint256 wethAmountPerToken = amountWETH >> 1;

		// Swap WETH for the specified tokens
		uint256 amountA = pools.depositSwapWithdraw( weth, tokenA, wethAmountPerToken, 0, block.timestamp );
		uint256 amountB = pools.depositSwapWithdraw( weth, tokenB, wethAmountPerToken, 0, block.timestamp );

		// Transfer the tokens to the DAO
		tokenA.safeTransfer( address(dao), amountA );
		tokenB.safeTransfer( address(dao), amountB );

		// Have the DAO form POL
		dao.formPOL(tokenA, tokenB, amountA, amountB);
		}


	// 3. Convert a default 5% of the remaining WETH to USDS/DAI Protocol Owned Liquidity.
	function step3() public onlySameContract
		{
		uint256 wethBalance = weth.balanceOf( address(this) );
		if ( wethBalance == 0 )
			return;

		// A default 5% of the remaining WETH will be swapped for USDS/DAI POL.
		uint256 amountOfWETH = wethBalance * stableConfig.percentArbitrageProfitsForStablePOL() / 100;
		_formPOL(usds, dai, amountOfWETH);
		}


	// 4. Convert a default 20% of the remaining WETH to SALT/USDS Protocol Owned Liquidity.
	function step4() public onlySameContract
		{
		uint256 wethBalance = weth.balanceOf( address(this) );
		if ( wethBalance == 0 )
			return;

		// A default 20% of the remaining WETH will be swapped for SALT/USDS POL.
		uint256 amountOfWETH = wethBalance * daoConfig.arbitrageProfitsPercentPOL() / 100;
		_formPOL(salt, usds, amountOfWETH);
		}


	// 5. Convert remaining WETH to SALT and sends it to SaltRewards.
	function step5() public onlySameContract
		{
		uint256 wethBalance = weth.balanceOf( address(this) );
		if ( wethBalance == 0 )
			return;

		// Convert remaining WETH to SALT and send it to SaltRewards
		uint256 amountSALT = pools.depositSwapWithdraw( weth, salt, wethBalance, 0, block.timestamp );
		salt.safeTransfer(address(saltRewards), amountSALT);
		}


	// 6. Send SALT Emissions to the SaltRewards contract.
	function step6() public onlySameContract
		{
		uint256 timeSinceLastUpkeep = block.timestamp - lastUpkeepTimeEmissions;
		emissions.performUpkeep(timeSinceLastUpkeep);

		lastUpkeepTimeEmissions = block.timestamp;
		}


	// 7. Distribute SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter.
	function step7() public onlySameContract
		{
		uint256[] memory profitsForPools = pools.profitsForWhitelistedPools();

		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();
		saltRewards.performUpkeep(poolIDs, profitsForPools );
		pools.clearProfitsForPools();
		}


	// 8. Distribute SALT rewards from the stakingRewardsEmitter and liquidityRewardsEmitter.
	function step8() public onlySameContract
		{
		uint256 timeSinceLastUpkeep = block.timestamp - lastUpkeepTimeRewardsEmitters;

		saltRewards.stakingRewardsEmitter().performUpkeep(timeSinceLastUpkeep);
		saltRewards.liquidityRewardsEmitter().performUpkeep(timeSinceLastUpkeep);

		lastUpkeepTimeRewardsEmitters = block.timestamp;
		}


	// 9. Collect SALT rewards from the DAO's Protocol Owned Liquidity (SALT/USDS from formed POL), send 10% to the initial dev team and burn a default 50% of the remaining - the rest stays in the DAO.
	function step9() public onlySameContract
		{
		dao.processRewardsFromPOL();
		}


	// 10. Send SALT from the DAO vesting wallet to the DAO (linear distribution over 10 years).
	function step10() public onlySameContract
		{
		VestingWallet(payable(exchangeConfig.daoVestingWallet())).release(address(salt));
		}


	// 11. Sends SALT from the team vesting wallet to the team (linear distribution over 10 years).
	function step11() public onlySameContract
		{
		uint256 releaseableAmount = VestingWallet(payable(exchangeConfig.teamVestingWallet())).releasable(address(salt));

		// teamVestingWallet actually sends the vested SALT to this contract - which will then need to be sent to the active teamWallet
		VestingWallet(payable(exchangeConfig.teamVestingWallet())).release(address(salt));

		salt.safeTransfer( exchangeConfig.managedTeamWallet().mainWallet(), releaseableAmount );
		}


	// Perform the various steps of performUpkeep as outlined at the top of the contract.
	// Each step is wrapped in a try/catch to prevent reversions from cascading through the performUpkeep.
	function performUpkeep() public nonReentrant
		{
		// Perform the multiple steps of performUpkeep()
 		try this.step1() {}
		catch (bytes memory error) { emit UpkeepError("Step 1", error); }

 		try this.step2(msg.sender) {}
		catch (bytes memory error) { emit UpkeepError("Step 2", error); }

 		try this.step3() {}
		catch (bytes memory error) { emit UpkeepError("Step 3", error); }

 		try this.step4() {}
		catch (bytes memory error) { emit UpkeepError("Step 4", error); }

 		try this.step5() {}
		catch (bytes memory error) { emit UpkeepError("Step 5", error); }

 		try this.step6() {}
		catch (bytes memory error) { emit UpkeepError("Step 6", error); }

 		try this.step7() {}
		catch (bytes memory error) { emit UpkeepError("Step 7", error); }

 		try this.step8() {}
		catch (bytes memory error) { emit UpkeepError("Step 8", error); }

 		try this.step9() {}
		catch (bytes memory error) { emit UpkeepError("Step 9", error); }

 		try this.step10() {}
		catch (bytes memory error) { emit UpkeepError("Step 10", error); }

 		try this.step11() {}
		catch (bytes memory error) { emit UpkeepError("Step 11", error); }
		}


	// ==== VIEWS ====
	// Returns the amount of WETH that will currently be rewarded for calling performUpkeep().
	// Useful for potential callers to know if calling the function will be profitable in comparison to current gas costs.
	function currentRewardsForCallingPerformUpkeep() public view returns (uint256)
		{
		uint256 daoWETH = pools.depositedUserBalance( address(dao), weth );

		return daoWETH * daoConfig.upkeepRewardPercent() / 100;
		}
	}
