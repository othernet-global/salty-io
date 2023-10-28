// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../../rewards/interfaces/ISaltRewards.sol";
import "../../interfaces/ISalt.sol";
import "../../stable/interfaces/IUSDS.sol";
import "../../staking/interfaces/ILiquidity.sol";


interface IDAO
	{
	function finalizeBallot( uint256 ballotID ) external;
	function sufficientBootstrappingRewardsExistForWhitelisting() external view returns (bool);
	function countryIsExcluded( string calldata country ) external view returns (bool);

	function withdrawArbitrageProfits( IERC20 weth ) external;
	function formPOL( ICollateralAndLiquidity collateralAndLiquidity, ISalt salt, IUSDS usds ) external;
	function sendSaltToSaltRewards( ISalt salt, ISaltRewards saltRewards, uint256 amountToSend) external;
	function processRewardsFromPOL(ICollateralAndLiquidity collateralAndLiquidity, ISalt salt, IUSDS usds) external;

	function initialGeoExclusion(uint256[] memory geoExclusionYes, uint256[] memory geoExclusionNo) external;

	// Views
	function pools() external returns (IPools);
	function websiteURL() external returns (string memory);
	}