pragma solidity =0.8.20;

import "../openzeppelin/token/ERC20/IERC20.sol";


contract ArbitrageProfits
	{
	address public ARB_MANAGER;

	// The profits (in WETH) that were contributed by each pool since the last performUpkeep was called.
	// These will be referenced on performUpkeep to send rewards to pools proportional to the contribution they made towards generating arbitrage profits.
	// After the proportional rewards are sent, the mappings are cleared.
	mapping(bytes32=>uint256) public profitsForPools;


	constructor()
		{
		ARB_MANAGER = address(this);
		}


	function _updateArbitrageStats( bytes32[] memory arbitragePathPoolIDs, uint256 arbitrageProfit ) internal
		{
		if ( ( arbitragePathPoolIDs.length == 0 ) || ( arbitrageProfit == 0 ) )
			return;

		// Evenly divide the profits between the pools that participated in the arbitrage
		uint256 profitPerPool = arbitrageProfit / arbitragePathPoolIDs.length;

		for( uint256 i = 0; i < arbitragePathPoolIDs.length; i++ )
			profitsForPools[ arbitragePathPoolIDs[i] ] += profitPerPool;
		}


//	function performUpkeep()
//		{
//		// Clear profitsForPools;
//		}
	}
