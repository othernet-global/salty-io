// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../pools/interfaces/IPools.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../price_feed/interfaces/IPriceAggregator.sol";
import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IDAOConfig.sol";


// Performs the following upkeep on the exchange for each call to DAO.performUpkeep():
// 1. Updates the prices of BTC and ETH in the PriceAggregator.
// 2. Withdraws the WETH deposited in the Pools contract (from previous automatic arbitrage).
// 3. Sends a default 5% of the withdrawn WETH to the caller of performUpkeep().
// 4. Send 85% of the remaining withdrawn WETH to the Pools.WETH_SALT_BUFFER so that it can gradually be converted to SALT without haveing to worry about frontrunning.
// 5. Withdraw converted SALT from the Pools.WETH_SALT_BUFFER.
// 5. Converts any remaining WETH to SALT and sends it to the SaltRewards contract (to be sent in a later step to the stakingRewardsEmitter and liquidityRewardsEmitter).
// 6. Sends SALT Emissions to the SaltRewards contract.
// 7. Distributes SALT from SaltRewards to the stakingRewardsEmitter and liquidityRewardsEmitter using SaltRewards.performUpkeep();
// 8. Sells liquidated WBTC and WETH to burn the required amount of USDS from liquidated collateral positions.
// 9. Collects SALT rewards from Protocol Owned Liquidity (SALT/WBTC, SALT/WETH or SALT/USDS): burns 45% and sends 10% to the team.
// 10. Releases SALT from the DAO vesting wallet (linear distribution over 10 years).
// 11. Releases SALT from the Team vesting wallet (linear distribution over 10 years).


contract UpkeepPerformer
    {
	using SafeERC20 for ISalt;
	using SafeERC20 for IERC20;

    event UpkeepError(string description, bytes error);

	IPools immutable public pools;
	IExchangeConfig  immutable public exchangeConfig;
	IERC20  immutable public wbtc;
	IERC20  immutable public weth;
	ISalt  immutable public salt;
	IUSDS  immutable public usds;

	uint256 public lastUpkeepTime;


    constructor( IPools _pools, IExchangeConfig _exchangeConfig )
		{
		require( address(_pools) != address(0), "_pools cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		pools = _pools;
		exchangeConfig = _exchangeConfig;

		// Cached for efficiency
		wbtc = _exchangeConfig.wbtc();
		weth = _exchangeConfig.weth();
		salt = _exchangeConfig.salt();
		usds = _exchangeConfig.usds();

		lastUpkeepTime = block.timestamp;
		}


	// 1. Update the prices of BTC and ETH in the PriceAggregator.
	function step1( IPriceAggregator priceAggregator ) public
		{
		require( msg.sender == address(this), "Only callable from within the same contract" );

 		priceAggregator.performUpkeep();
		}


	// 2. Withdraw the WETH deposited in the Pools contract (from previous automatic arbitrage).
	function step2() public
		{
		require( msg.sender == address(this), "Only callable from within the same contract" );

		uint256 depositedWETH =  pools.depositedBalance(address(this), weth );
		pools.withdraw( weth, depositedWETH );
		}


	// 3. Send a default 5% of the withdrawn WETH to the caller of performUpkeep().
	function step3( IDAOConfig daoConfig ) public
		{
		require( msg.sender == address(this), "Only callable from within the same contract" );

		uint256 wethBalance = weth.balanceOf( address(this) );
		uint256 rewardAmount = wethBalance * daoConfig.upkeepRewardPercent() / 100;

		// Send the reward
		weth.safeTransfer(msg.sender, rewardAmount);
		}


	// 4. Uses a default 30% of the remaining WETH to form the highest yield POL - choosing from the SALT/WBTC, SALT/WETH and SALT/USDS pools.
	function step4( IDAOConfig daoConfig ) public
		{
		require( msg.sender == address(this), "Only callable from within the same contract" );

		uint256 wethBalance = weth.balanceOf( address(this) );
		uint256 saltAmountForPOL = wethBalance * daoConfig.daoArbitragePercent() / 100;


//		incomplete
		}


	// Perform the various steps of performUpkeep as outlined at the top of the contract.
	// Each step is wrapped in a try/catch and called using this.stepX() - with each stepX function requiring that the caller has to be this contract.
	function _performUpkeep( IPriceAggregator priceAggregator, IPoolsConfig poolsConfig, IDAOConfig daoConfig ) internal
		{
		uint256 timeSinceLastUpkeep = block.timestamp - lastUpkeepTime;

		bytes32[] memory poolIDs = poolsConfig.whitelistedPools();

		// Perform the multiple steps to perform upkeep.
		// Try/catch blocks are used to prevent any of the steps (which are not independent from previosu steps) from reverting the transaction.
 		try this.step1(priceAggregator) {}
		catch (bytes memory error) { emit UpkeepError("Step 1", error); }

 		try this.step2() {}
		catch (bytes memory error) { emit UpkeepError("Step 2", error); }

 		try this.step3(daoConfig) {}
		catch (bytes memory error) { emit UpkeepError("Step 3", error); }

 		try this.step4(daoConfig) {}
		catch (bytes memory error) { emit UpkeepError("Step 4", error); }

		lastUpkeepTime = block.timestamp;
		}
	}
