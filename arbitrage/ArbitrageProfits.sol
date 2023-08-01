pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/IERC20.sol";
import "../interfaces/IExchangeConfig.sol";


contract ArbitrageProfits
	{
	IExchangeConfig immutable public exchangeConfig;

	// The profits (in WETH) that were contributed by each pool since the last performUpkeep was called.
	// These will be referenced on performUpkeep to send rewards to pools proportional to the contribution they made in generating the arbitrage profits.
	// After the proportional rewards are sent, the mappings are cleared for all whitelisted poolIDs.
	mapping(bytes32=>uint256) public profitsForPools;


	constructor( IExchangeConfig _exchangeConfig )
		{
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );

		exchangeConfig = _exchangeConfig;
		}


	function _updateArbitrageStats( bytes32[] memory arbitragePathPoolIDs, uint256 arbitrageProfit ) internal
		{
		if ( arbitrageProfit == 0 )
			return;

		// Evenly divide the profits between the pools that participated in the arbitrage
		uint256 profitPerPool = arbitrageProfit / arbitragePathPoolIDs.length;

		for( uint256 i = 0; i < arbitragePathPoolIDs.length; i++ )
			profitsForPools[ arbitragePathPoolIDs[i] ] += profitPerPool;
		}


	function clearProfitsForPools( bytes32[] memory poolIDs ) public
		{
		require( msg.sender == address(exchangeConfig.dao()), "ArbitrageProfits.performUpkeep only callable from the DAO contract" );

		for( uint256 i = 0; i < poolIDs.length; i++ )
			profitsForPools[ poolIDs[i] ] = 0;
		}
	}
