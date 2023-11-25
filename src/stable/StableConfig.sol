// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./interfaces/IStableConfig.sol";


// Contract owned by the DAO with parameters modifiable only by the DAO
contract StableConfig is IStableConfig, Ownable
    {
    event RewardPercentForCallingLiquidationChanged(uint256 newRewardPercent);
    event MaxRewardValueForCallingLiquidationChanged(uint256 newMaxRewardValue);
    event MinimumCollateralValueForBorrowingChanged(uint256 newMinimumCollateralValue);
    event InitialCollateralRatioPercentChanged(uint256 newInitialCollateralRatioPercent);
    event MinimumCollateralRatioPercentChanged(uint256 newMinimumCollateralRatioPercent);
    event PercentArbitrageProfitsForStablePOLChanged(uint256 newPercentArbitrageProfits);

	// The reward (in collateraLP) that a user receives for instigating the liquidation process - as a percentage of the amount of collateralLP that is liquidated.
	// Range: 5 to 10 with an adjustment of 1
    uint256 public rewardPercentForCallingLiquidation = 5;

	// The maximum reward value (in USD) that a user receives for instigating the liquidation process.
	// Range: 100 to 1000 with an adjustment of 100 ether
    uint256 public maxRewardValueForCallingLiquidation = 500 ether;

	// The minimum USD value of collateral - to borrow an initial amount of USDS.
	// This is to help prevent saturation of the contract with small amounts of positions and to ensure that liquidating the position yields non-trivial rewards
	// Range: 1000 to 5000 with an adjustment of 500 ether
    uint256 public minimumCollateralValueForBorrowing = 2500 ether;

    // the initial maximum collateral / borrowed USDS ratio.
    // Defaults to 2.0x so that staking $1000 worth of BTC/ETH LP would allow you to borrow $500 of USDS
    // Range: 150 to 300 with an adjustment of 25
    uint256 public initialCollateralRatioPercent = 200;

	// The minimum ratio of collateral / borrowed USDS below which positions can be liquidated
	// and the user losing their collateral (and keeping the borrowed USDS)
	// Range: 110 to 120 with an adjustment of 1
	uint256 public minimumCollateralRatioPercent = 110;

	// The percent of arbitrage profits that are used to form USDS/DAI Protocol Owned Liquidity.
	// The liquidity generates yield for the DAO and can be liquidated in the event of undercollateralized liquidations.
	// Range: 1 to 10 with an adjustment of 1
	uint256 public percentArbitrageProfitsForStablePOL = 5;


	function changeRewardPercentForCallingLiquidation(bool increase) external onlyOwner
        {
        if (increase)
            {
			// Don't increase rewardPercentForCallingLiquidation if the remainingRatio after the rewards would be less than 105% - to ensure that the position will be liquidatable for more than the originally borrowed USDS amount (assume reasonable market volatility)
			uint256 remainingRatioAfterReward = minimumCollateralRatioPercent - rewardPercentForCallingLiquidation - 1;

            if (remainingRatioAfterReward >= 105 && rewardPercentForCallingLiquidation < 10)
                rewardPercentForCallingLiquidation += 1;
            }
        else
            {
            if (rewardPercentForCallingLiquidation > 5)
                rewardPercentForCallingLiquidation -= 1;
            }

		emit RewardPercentForCallingLiquidationChanged(rewardPercentForCallingLiquidation);
        }


	function changeMaxRewardValueForCallingLiquidation(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (maxRewardValueForCallingLiquidation < 1000 ether)
                maxRewardValueForCallingLiquidation += 100 ether;
            }
        else
            {
            if (maxRewardValueForCallingLiquidation > 100 ether)
                maxRewardValueForCallingLiquidation -= 100 ether;
            }

		emit MaxRewardValueForCallingLiquidationChanged(maxRewardValueForCallingLiquidation);
        }


	function changeMinimumCollateralValueForBorrowing(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (minimumCollateralValueForBorrowing < 5000 ether)
                minimumCollateralValueForBorrowing += 500 ether;
            }
        else
            {
            if (minimumCollateralValueForBorrowing > 1000 ether)
                minimumCollateralValueForBorrowing -= 500 ether;
            }

		emit MinimumCollateralValueForBorrowingChanged(minimumCollateralValueForBorrowing);
        }


	function changeInitialCollateralRatioPercent(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (initialCollateralRatioPercent < 300)
                initialCollateralRatioPercent += 25;
            }
        else
            {
            if (initialCollateralRatioPercent > 150)
                initialCollateralRatioPercent -= 25;
            }

		emit InitialCollateralRatioPercentChanged(initialCollateralRatioPercent);
        }


	function changeMinimumCollateralRatioPercent(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (minimumCollateralRatioPercent < 120)
                minimumCollateralRatioPercent += 1;
            }
        else
            {
			// Don't decrease the minimumCollateralRatioPercent if the remainingRatio after the rewards would be less than 105% - to ensure that the position will be liquidatable for more than the originally borrowed USDS amount (assume reasonable market volatility)
			uint256 remainingRatioAfterReward = minimumCollateralRatioPercent - 1 - rewardPercentForCallingLiquidation;

            if (remainingRatioAfterReward >= 105 && minimumCollateralRatioPercent > 110)
                minimumCollateralRatioPercent -= 1;
            }

		emit MinimumCollateralRatioPercentChanged(minimumCollateralRatioPercent);
        }


	function changePercentArbitrageProfitsForStablePOL(bool increase) external onlyOwner
        {
        if (increase)
            {
            if (percentArbitrageProfitsForStablePOL < 10)
                percentArbitrageProfitsForStablePOL += 1;
            }
        else
            {
            if (percentArbitrageProfitsForStablePOL > 1)
                percentArbitrageProfitsForStablePOL -= 1;
            }

		emit PercentArbitrageProfitsForStablePOLChanged(percentArbitrageProfitsForStablePOL);
        }
	}