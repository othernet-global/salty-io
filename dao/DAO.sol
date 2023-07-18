// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../rewards/interfaces/IRewardsConfig.sol";
import "../stable/interfaces/IStableConfig.sol";
import "../staking/interfaces/ILiquidity.sol";
import "../staking/interfaces/IStaking.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../Upkeepable.sol";
import "./interfaces/ICalledContract.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IProposals.sol";
import "../interfaces/IAccessManager.sol";
import "./interfaces/IDAO.sol";
import "../pools/PoolUtils.sol";
import "./Parameters.sol";


// Allows users to propose and vote on various governance actions such as changing parameters, whitelisting/unwhitelisting tokens, sending tokens, calling other contracts, and updating the website.
// It handles proposing ballots, tracking votes, enforcing voting requirements, and executing approved proposals.
// It also stores SALT in the contract for later use and WETH for forming Protocol Owned Liquidity of either SALT/WBTC, SALT/WETH or SALT/USDS.
contract DAO is IDAO, Upkeepable, Parameters
    {
	using SafeERC20 for IERC20;

	IExchangeConfig public exchangeConfig;
	IPoolsConfig public poolsConfig;
	IStakingConfig public stakingConfig;
	IDAOConfig public daoConfig;
	IRewardsConfig public rewardsConfig;
	IStableConfig public stableConfig;
	ILiquidity public liquidity;
	IRewardsEmitter public liquidityRewardsEmitter;

	// The default IPFS URL for the website content (can be changed with a setWebsiteURL proposal)
	string public websiteURL;

	// Countries that have been excluded from access to the DEX (used by AccessManager.sol)
	mapping(string=>bool) public excludedCountries;

	// Contract which handles the proposals submitted by DAO members
	IProposals public proposals;


    constructor( IProposals _proposals, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig, IDAOConfig _daoConfig, IRewardsConfig _rewardsConfig, IStableConfig _stableConfig, ILiquidity _liquidity, IRewardsEmitter _liquidityRewardsEmitter )
		{
		require( address(_proposals) != address(0), "_proposals cannot be address(0)" );
		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
		require( address(_poolsConfig) != address(0), "_poolsConfig cannot be address(0)" );
		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );
		require( address(_daoConfig) != address(0), "_daoConfig cannot be address(0)" );
		require( address(_rewardsConfig) != address(0), "_rewardsConfig cannot be address(0)" );
		require( address(_stableConfig) != address(0), "_stableConfig cannot be address(0)" );
		require( address(_liquidity) != address(0), "_liquidity cannot be address(0)" );
		require( address(_liquidityRewardsEmitter) != address(0), "_liquidityRewardsEmitter cannot be address(0)" );

		proposals = _proposals;
		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;
		stakingConfig = _stakingConfig;
		daoConfig = _daoConfig;
		rewardsConfig = _rewardsConfig;
		stableConfig = _stableConfig;
        liquidity = _liquidity;
        liquidityRewardsEmitter = _liquidityRewardsEmitter;

		// Approve SALT to be sent to the liquidityRewardsEmitter as bootstrapping rewards for whitelisted tokens
		exchangeConfig.salt().approve( address(liquidityRewardsEmitter), type(uint256).max );
        }


	// Performs upkeep on the exchange, handling various housekeeping functions such as:
	// Emissions - distributing SALT rewards to the stakingRewardsEmitter and liquidityRewardsEmitter
	// AAA - converting previous arbitrage profits from WETH to SALT and sending them to the releveant RewardsEmitters
	// RewardsEmitters - for staking, liquidity and collateral SALT rewards distribution.
	// Liquidator - liquidating any LP that is currently being held in the Liquidator contract, burning the required amount of USDS and sending extra WETH to the POL_Optimizer.
	// POL_Optimizer - forming optimized Protocol Owned Liquidity with the WETH it has been sent.
	// DAO - staking any LP that was sent to it by the POL_Optimizer.

	// The caller of performUpkeep receives a share of the DAO Protocol Owned Liquidity profits that are claimed during the upkeep and also
	// receives any WETH (swapped to SALT) that was sent by the AAA on its performUpkeep.

	function _performUpkeep() internal override
		{
		}


	// Finalize the vote for a parameter ballot (increase, decrease or no_change) for a given parameter
	function _finalizeParameterBallot( uint256 ballotID ) internal
		{
		Ballot memory ballot = proposals.ballotForID(ballotID);

		Vote winningVote = proposals.winningParameterVote(ballotID);

		if ( winningVote == Vote.INCREASE )
			_executeParameterChange( ParameterTypes(ballot.number1), true, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig );
		else if ( winningVote == Vote.DECREASE )
			_executeParameterChange( ParameterTypes(ballot.number1), false, poolsConfig, stakingConfig, rewardsConfig, stableConfig, daoConfig );

		proposals.markBallotAsFinalized(ballotID);
		}


	function _executeSetContract( Ballot memory ballot ) internal
		{
		bytes32 nameHash = keccak256(bytes( ballot.ballotName ) );

		if ( nameHash == keccak256(bytes( "setContract:priceFeed" )) )
			stableConfig.setPriceFeed( IPriceFeed(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:AAA" )) )
			exchangeConfig.setAAA( IAAA(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:accessManager" )) )
			exchangeConfig.setAccessManager( IAccessManager(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:stakingRewardsEmitter" )) )
			exchangeConfig.setStakingRewardsEmitter( IRewardsEmitter(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:liquidityRewardsEmitter" )) )
			exchangeConfig.setLiquidityRewardsEmitter( IRewardsEmitter(ballot.address1) );
		else if ( nameHash == keccak256(bytes( "setContract:collateralRewardsEmitter" )) )
			exchangeConfig.setCollateralRewardsEmitter( IRewardsEmitter(ballot.address1) );
		}


	function _executeSetWebsiteURL( Ballot memory ballot ) internal
		{
		websiteURL = ballot.string1;
		}


	function _executeApproval( Ballot memory ballot ) internal
		{
		if ( ballot.ballotType == BallotType.UNWHITELIST_TOKEN )
			{
			// All tokens are paired with both WBTC and WETH so unwhitelist those pools
			poolsConfig.unwhitelistPool( IERC20(ballot.address1), exchangeConfig.wbtc() );
			poolsConfig.unwhitelistPool( IERC20(ballot.address1), exchangeConfig.weth() );
			}

		else if ( ballot.ballotType == BallotType.SEND_SALT )
			{
			// Make sure the contract has the SALT balance before trying to send it
			// This should not happen but is here just in case - to prevent approved proposals from reverting on finalization
			if ( exchangeConfig.salt().balanceOf(address(this)) >= ballot.number1 )
				IERC20(exchangeConfig.salt()).safeTransfer( ballot.address1, ballot.number1 );
			}

		else if ( ballot.ballotType == BallotType.CALL_CONTRACT )
			ICalledContract(ballot.address1).callFromDAO( ballot.number1 );

		else if ( ballot.ballotType == BallotType.INCLUDE_COUNTRY )
			excludedCountries[ ballot.string1 ] = false;

		else if ( ballot.ballotType == BallotType.EXCLUDE_COUNTRY )
			excludedCountries[ ballot.string1 ] = true;

		// Once an initial setContract proposal passes, it automatically starts a second confirmation ballot (to prevent last minute approvals)
		else if ( ballot.ballotType == BallotType.SET_CONTRACT )
			proposals.createConfirmationProposal( string.concat(ballot.ballotName, "_confirm"), BallotType.CONFIRM_SET_CONTRACT, ballot.address1, "" );

		// Once an initial setWebsiteURL proposal passes, it automatically starts a second confirmation ballot (to prevent last minute approvals)
		else if ( ballot.ballotType == BallotType.SET_WEBSITE_URL )
			proposals.createConfirmationProposal( string.concat(ballot.ballotName, "_confirm"), BallotType.CONFIRM_SET_WEBSITE_URL, address(0), ballot.string1 );

		else if ( ballot.ballotType == BallotType.CONFIRM_SET_CONTRACT )
			_executeSetContract( ballot );

		else if ( ballot.ballotType == BallotType.CONFIRM_SET_WEBSITE_URL )
			_executeSetWebsiteURL( ballot );
		}


	// Finalize the vote for an approval ballot (yes or no) for a given proposal
	function _finalizeApprovalBallot( uint256 ballotID ) internal
		{
		if ( proposals.ballotIsApproved(ballotID ) )
			{
			Ballot memory ballot = proposals.ballotForID(ballotID);
			_executeApproval( ballot );
			}

		proposals.markBallotAsFinalized(ballotID);
		}


	// Finalize and execute a token whitelisting ballot.
	// If the proposal is currently the whitelisting proposal with the most yes votes then the token can be whitelisted.
	// If NO > YES than the proposal is removed (quorum would already have been determined - in canFinalizeBallot as called from finalizeBallot).
	function _finalizeTokenWhitelisting( uint256 ballotID ) internal
		{
		if ( proposals.ballotIsApproved(ballotID ) )
			{
			Ballot memory ballot = proposals.ballotForID(ballotID);

			// Fail if we don't have enough rewards in the DAO for bootstrapping new tokens
			require( sufficientBootstrappingRewardsExistForWhitelisting(), "Whitelisting is not currently possible due to insufficient bootstrapping rewards" );

			// If yes is higher then fail to whitelist for now if this isn't the whitelisting proposal with the most votes
			uint256 bestWhitelistingBallotID = proposals.tokenWhitelistingBallotWithTheMostVotes();
			require( bestWhitelistingBallotID == ballotID, "Only the token whitelisting ballot with the most votes can be finalized" );

			// All tokens are paired with both WBTC and WETH, so whitelist both pairings
			poolsConfig.whitelistPool( IERC20(ballot.address1), exchangeConfig.wbtc() );
			poolsConfig.whitelistPool( IERC20(ballot.address1), exchangeConfig.weth() );

			(bytes32 pool1,) = PoolUtils.poolID( IERC20(ballot.address1), exchangeConfig.wbtc() );
			(bytes32 pool2,) = PoolUtils.poolID( IERC20(ballot.address1), exchangeConfig.weth() );

			// Send the initial bootstrappingRewards to promote initial liquidity on these two newly whitelisted pools
			AddedReward[] memory addedRewards = new AddedReward[](2);
			addedRewards[0] = AddedReward( pool1, daoConfig.bootstrappingRewards() );
			addedRewards[1] = AddedReward( pool2, daoConfig.bootstrappingRewards() );

			liquidityRewardsEmitter.addSALTRewards( addedRewards );
			}

		// Mark the ballot as finalized (which will also remove it from the list of open token whitelisting proposals)
		proposals.markBallotAsFinalized(ballotID);
		}


	// Finalize the vote on a specific ballot
	function finalizeBallot( uint256 ballotID ) public nonReentrant
		{
		// Checks that ballot is live, and minimumEndTime and quorum have both been reached
		require( proposals.canFinalizeBallot(ballotID), "The ballot is not yet able to be finalized" );

		Ballot memory ballot = proposals.ballotForID(ballotID);

		if ( ballot.ballotType == BallotType.PARAMETER )
			_finalizeParameterBallot(ballotID);
		else if ( ballot.ballotType == BallotType.WHITELIST_TOKEN )
			_finalizeTokenWhitelisting(ballotID);
		else
			_finalizeApprovalBallot(ballotID);
		}


	// === VIEWS ===

	// Finalization only possible for whitelisting tokens if the SALT balance in the DAO contract satisfies the bootstrapping rewards (as specified in daoConfig).
	function sufficientBootstrappingRewardsExistForWhitelisting() public view returns (bool)
		{
		// Make sure that the DAO contracts holds the required amount of SALT for bootstrappingRewards.
		// Twice the specified rewards are needed (for both the token/WBTC and token/WETH pools which will be whitelisted)
		uint256 saltBalance = exchangeConfig.salt().balanceOf( address(this) );
		if ( saltBalance < daoConfig.bootstrappingRewards() * 2 )
			return false;

		return true;
		}


	function countryIsExcluded( string memory country ) public view returns (bool)
		{
		return excludedCountries[country];
		}
	}