//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "../rewards/interfaces/IRewardsConfig.sol";
//import "../stable/interfaces/IStableConfig.sol";
//import "../rewards/interfaces/IRewardsEmitter.sol";
//import "../Upkeepable.sol";
//import "./interfaces/ICalledContract.sol";
//import "./Proposals.sol";
//import "../interfaces/IAccessManager.sol";
//import "./interfaces/IDAO.sol";
//import "../staking/interfaces/ILiquidity.sol";
//
//// Contract store SALT for bootstrapping rewards or for sending
//contract DAO is IDAO, Upkeepable, Proposals
//    {
//	using SafeERC20 for IERC20;
//    using EnumerableSet for EnumerableSet.UintSet;
//
//	IRewardsConfig public rewardsConfig;
//	IStableConfig public stableConfig;
//	ILiquidity public liquidity;
//	IRewardsEmitter public liquidityRewardsEmitter;
//
//	// The ballotIDs of the tokens currently being proposed for whitelisting
//	EnumerableSet.UintSet private _openBallotsForTokenWhitelisting;
//
//	// The default IPFS URL for the website content (can be changed with SET_WEBSITE_URL for content updates)
//	string public websiteURL;
//
//	// Countries that have excluded from access to the DEX (used by AccessManager.sol)
//	mapping(string=>bool) public excludedCountries;
//
//
//    constructor( IStakingConfig _stakingConfig, IDAOConfig _daoConfig, IExchangeConfig _exchangeConfig, IStakingRewards _staking, IRewardsConfig _rewardsConfig, IStableConfig _stableConfig, ILiquidity _liquidity, IRewardsEmitter _liquidityRewardsEmitter, IUniswapV2Factory _factory )
//    Proposals( _stakingConfig, _daoConfig, _exchangeConfig, _staking, _factory )
//		{
//		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );
//		require( address(_stableConfig) != address(0), "_stableConfig cannot be address(0)" );
//		require( address(_liquidity) != address(0), "_liquidity cannot be address(0)" );
//		require( address(_liquidityRewardsEmitter) != address(0), "_liquidityRewardsEmitter cannot be address(0)" );
//
//		rewardsConfig = _rewardsConfig;
//		stableConfig = _stableConfig;
//        liquidity = _liquidity;
//        liquidityRewardsEmitter = _liquidityRewardsEmitter;
//
//		// Approve SALT to be sent to the liquidityRewardsEmitter as bootstrapping rewards for whitelisted tokens
//		stakingConfig.salt().approve( address(liquidityRewardsEmitter), type(uint256).max );
//        }
//
//
//	// Performs upkeep on the exchange, handling various housekeeping functions such as:
//	// Emissions - distributing SALT rewards to the stakingRewardsEmitter and liquidityRewardsEmitter
//	// AAA - converting previous arbitrage profits from WETH to SALT and sending them to the releveant RewardsEmitters
//	// RewardsEmitters - for staking, liquidity and collateral SALT rewards distribution.
//	// Liquidator - liquidating any LP that is currently being held in the Liquidator contract, burning the required amount of USDS and sending extra WETH to the POL_Optimizer.
//	// POL_Optimizer - forming optimized Protocol Owned Liquidity with the WETH it has been sent.
//	// DAO - staking any LP that was sent to it by the POL_Optimizer.
//
//	// The caller of performUpkeep receives a share of the DAO Protocol Owned Liquidity profits that are claimed during the upkeep and also
//	// receives any WETH (swapped to SALT) that was sent by the AAA on its performUpkeep.
//
//	function _performUpkeep() internal override
//		{
//		// Scan to see if we have any LP tokens from any of the whitelisted pools and then stake it.
//		// This LP would have been formed and sent to this contract earlier by POL_Optimizer during its _performUpkeep()
//        IUniswapV2Pair[] memory pools = stakingConfig.whitelistedPools();
//
//		for( uint256 i = 0; i < pools.length; i++ )
//			{
//			IUniswapV2Pair pool = pools[i];
//
//			uint256 lpBalance = pool.balanceOf( address(this) );
//
//			// Stake any non-zero balance into the Liquidity SharedRewards contract
//			if( lpBalance > 0 )
//				{
//				pool.approve( address(liquidity), lpBalance );
//				liquidity.stake( pool, lpBalance );
//				}
//			}
//		}
//
//
//	// Finalize the vote for a parameter ballot (increase, decrease or no_change) for a given parameter
//	function _finalizeParameterBallot( uint256 ballotID ) internal
//		{
//		uint256 increaseTotal = votesCastForBallot[ballotID][Vote.INCREASE];
//		uint256 decreaseTotal = votesCastForBallot[ballotID][Vote.DECREASE];
//		uint256 noChangeTotal = votesCastForBallot[ballotID][Vote.NO_CHANGE];
//
//		Ballot storage ballot = ballots[ballotID];
//
//		if ( increaseTotal > decreaseTotal )
//		if ( increaseTotal > noChangeTotal )
//			_executeParameterChange( ParameterTypes(ballot.number1), true, daoConfig, rewardsConfig, stableConfig, stakingConfig );
//
//		if ( decreaseTotal > increaseTotal )
//		if ( decreaseTotal > noChangeTotal )
//			_executeParameterChange(  ParameterTypes(ballot.number1), false, daoConfig, rewardsConfig, stableConfig, stakingConfig );
//
//		_markBallotAsFinalized( ballot );
//		}
//
//
//	function _executeSetContract( Ballot storage ballot ) internal
//		{
//		bytes32 nameHash = keccak256(bytes( ballot.ballotName ) );
//
//		if ( nameHash == keccak256(bytes( "setContract:priceFeed" )) )
//			stableConfig.setPriceFeed( IPriceFeed(ballot.address1) );
//		else if ( nameHash == keccak256(bytes( "setContract:liquidator" )) )
//			exchangeConfig.setLiquidator( ILiquidator(ballot.address1) );
//		else if ( nameHash == keccak256(bytes( "setContract:AAA" )) )
//			exchangeConfig.setAAA( IAAA(ballot.address1) );
//		else if ( nameHash == keccak256(bytes( "setContract:optimizer" )) )
//			exchangeConfig.setOptimizer( IPOL_Optimizer(ballot.address1) );
//		else if ( nameHash == keccak256(bytes( "setContract:accessManager" )) )
//			exchangeConfig.setAccessManager( IAccessManager(ballot.address1) );
//		}
//
//
//	function _executeSetWebsiteURL( Ballot storage ballot ) internal
//		{
//		websiteURL = ballot.string1;
//		}
//
//
//	function _executeApproval( Ballot storage ballot ) internal
//		{
//		if ( ballot.ballotType == BallotType.UNWHITELIST_TOKEN )
//			{
//			// All tokens are pair with both WBTC and WETH
//			stakingConfig.unwhitelist( IUniswapV2Pair(factory.getPair( ballot.address1, exchangeConfig.wbtc())));
//			stakingConfig.unwhitelist( IUniswapV2Pair(factory.getPair( ballot.address1, exchangeConfig.weth())));
//			}
//
//		else if ( ballot.ballotType == BallotType.SEND_SALT )
//			{
//			// Make sure the contract has the SALT balance before trying to send it
//			// This should not happen but is here just in case - to prevent an approved proposals from being unable to be finalized
//			if ( stakingConfig.salt().balanceOf(address(this)) >= ballot.number1 )
//				IERC20(stakingConfig.salt()).safeTransfer( ballot.address1, ballot.number1 );
//			}
//
//		else if ( ballot.ballotType == BallotType.CALL_CONTRACT )
//			ICalledContract(ballot.address1).callFromDAO( ballot.number1 );
//
//		else if ( ballot.ballotType == BallotType.INCLUDE_COUNTRY )
//			excludedCountries[ ballot.string1 ] = false;
//
//		else if ( ballot.ballotType == BallotType.EXCLUDE_COUNTRY )
//			excludedCountries[ ballot.string1 ] = true;
//
//		else if ( ballot.ballotType == BallotType.SET_CONTRACT )
//			_possiblyCreateProposal( string.concat(ballot.ballotName,  "_confirm" ), BallotType.CONFIRM_SET_CONTRACT, ballot.address1, 0, "", "", 0 );
//
//		else if ( ballot.ballotType == BallotType.SET_WEBSITE_URL )
//			_possiblyCreateProposal( string.concat(ballot.ballotName,  "_confirm" ), BallotType.CONFIRM_SET_WEBSITE_URL, address(0), 0, ballot.string1, "", 0 );
//
//		else if ( ballot.ballotType == BallotType.CONFIRM_SET_CONTRACT )
//			_executeSetContract( ballot );
//
//		else if ( ballot.ballotType == BallotType.CONFIRM_SET_WEBSITE_URL )
//			_executeSetWebsiteURL( ballot );
//		}
//
//
//	// Finalize the vote for an approval ballot (yes or no) for a given proposal
//	function _finalizeApprovalBallot( uint256 ballotID ) internal
//		{
//		uint256 yesTotal = votesCastForBallot[ballotID][Vote.YES];
//		uint256 noTotal = votesCastForBallot[ballotID][Vote.NO];
//
//		Ballot storage ballot = ballots[ballotID];
//
//		if ( yesTotal > noTotal )
//			_executeApproval( ballot );
//
//		_markBallotAsFinalized( ballot );
//		}
//
//
//	// Finalize and execute a token whitelisting ballot.
//	// If the proposal is currently the whitelisting proposal with the most yes votes then the token can be whitelisted.
//	// If NO > YES than the proposal is removed (quorum woudl already have been determined - in canFinalizeBallot as called from finalizeBallot).
//	function _finalizeTokenWhitelisting( uint256 ballotID ) internal
//		{
//		uint256 yesTotal = votesCastForBallot[ballotID][Vote.YES];
//		uint256 noTotal = votesCastForBallot[ballotID][Vote.NO];
//
//		Ballot storage ballot = ballots[ballotID];
//
//		// Make sure the YES > NO
//		if ( yesTotal > noTotal )
//			{
//			// Fail if we don't have enough rewards in the DAO for bootstrapping new tokens
//			require( sufficientBootstrappingRewardsExistForWhitelisting(), "Whitelisting is not currently possible due to insufficient bootstrapping rewards" );
//
//			// If yes is higher than fail to whitelist for now if this isn't the whitelisting proposal with the most votes
//			uint256 bestWhitelistingBallotID = tokenWhitelistingBallotWithTheMostVotes();
//			require( bestWhitelistingBallotID == ballotID, "Only the token whitelisting ballot with the most votes can be finalized" );
//
//			// All tokens are pair with both WBTC and WETH
//			IUniswapV2Pair pool1 = IUniswapV2Pair(factory.getPair( ballot.address1, exchangeConfig.wbtc()));
//			IUniswapV2Pair pool2 = IUniswapV2Pair(factory.getPair( ballot.address1, exchangeConfig.weth()));
//
//			stakingConfig.whitelist( pool1 );
//			stakingConfig.whitelist( pool2 );
//
//			// Send the initial bootstrappingRewards to promote initial liquidity on the newly whitelisted pools
//			AddedReward[] memory addedRewards = new AddedReward[](2);
//			addedRewards[0] = AddedReward( pool1, daoConfig.bootstrappingRewards() );
//			addedRewards[1] = AddedReward( pool2, daoConfig.bootstrappingRewards() );
//
//			liquidityRewardsEmitter.addSALTRewards( addedRewards );
//			}
//
//		// Remove the token from whitelisting contention wheter or not the proposal was approved above
//		_openBallotsForTokenWhitelisting.remove( ballotID );
//		_markBallotAsFinalized( ballot );
//		}
//
//
//	// Finalize the vote on a specific ballot
//	function finalizeBallot( uint256 ballotID ) public nonReentrant
//		{
//		require( canFinalizeBallot( ballotID ), "The ballot is not yet able to be finalized" );
//
//		Ballot storage ballot = ballots[ballotID];
//
//		if ( ballot.ballotType == BallotType.PARAMETER )
//			_finalizeParameterBallot( ballotID );
//		else if ( ballot.ballotType == BallotType.WHITELIST_TOKEN )
//			_finalizeTokenWhitelisting( ballotID );
//		else
//			_finalizeApprovalBallot( ballotID );
//		}
//
//
//	// === VIEWS ===
//
//	// Finalization only possible for whitelisting if the SALT balance in the DAO contract satisfies the bootstrapping rewards.
//	function sufficientBootstrappingRewardsExistForWhitelisting() public view returns (bool)
//		{
//		// Make sure that the DAO contracts holds the required amount of SALT for bootstrappingRewards
//		// Twice the specified rewards are need (for both the token/SALT and token/USDS pools which will be whitelisted)
//		uint256 saltBalance = stakingConfig.salt().balanceOf( address(this) );
//		if ( saltBalance < daoConfig.bootstrappingRewards() * 2 )
//			return false;
//
//		return true;
//		}
//
//
//	function countryIsExcluded( string memory country ) public view returns (bool)
//		{
//		return excludedCountries[country];
//		}
//	}