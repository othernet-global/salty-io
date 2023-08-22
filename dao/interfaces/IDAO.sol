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
	function formPOL( ISalt salt, IUSDS usds ) external;
	function sendSaltToSaltRewards( ISalt salt, ISaltRewards saltRewards, uint256 amountToSend) external;
	function processRewardsFromPOL(ILiquidity liquidity, ISalt salt, IERC20 weth, IUSDS usds) external;

	// Views
	function websiteURL() external returns (string memory);
	}