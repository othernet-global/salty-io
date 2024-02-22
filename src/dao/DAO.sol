// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../rewards/interfaces/IRewardsEmitter.sol";
import "../rewards/interfaces/IRewardsConfig.sol";
import "../interfaces/IExchangeConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "../interfaces/IAccessManager.sol";
import "./interfaces/ICalledContract.sol";
import "./interfaces/IProposals.sol";
import "./interfaces/IDAO.sol";
import "../pools/PoolUtils.sol";
import "./Parameters.sol";
import "../Upkeep.sol";


// Allows users to propose and vote on various governance actions such as changing parameters, whitelisting/unwhitelisting tokens, sending tokens, calling other contracts, and updating the website.
// It handles proposing ballots, tracking votes, enforcing voting requirements, and executing approved proposals.
contract DAO is IDAO, Parameters, ReentrancyGuard
    {
	event ParameterBallotFinalized(uint256 indexed ballotID, Vote winningVote);
    event SetAccessManager(address indexed contractAddress);
    event SetWebsiteURL(string newURL);
    event WhitelistToken(IERC20 indexed token);
    event UnwhitelistToken(IERC20 indexed token);
    event GeoExclusionUpdated(string country, bool excluded, uint256 geoVersion);
    event TokensWithdrawn(address indexed upkeepContract, IERC20 indexed token, uint256 withdrawnAmount);
    event SaltSent(address indexed to, uint256 amount);
    event ContractCalled(address indexed contractAddress, uint256 indexed intArg);
    event TeamRewardsTransferred(uint256 teamAmount);

	using SafeERC20 for ISalt;
	using SafeERC20 for IERC20;

	IPools immutable public pools;
	IProposals immutable public proposals;
	IExchangeConfig immutable public exchangeConfig;
	IPoolsConfig immutable public poolsConfig;
	IStakingConfig immutable public stakingConfig;
	IRewardsConfig immutable public rewardsConfig;
	IDAOConfig immutable public daoConfig;
	IRewardsEmitter immutable public liquidityRewardsEmitter;

	// The default IPFS URL for the website content (can be changed with a setWebsiteURL proposal)
	string public websiteURL;

	// Countries that have been excluded from access to the DEX (used by AccessManager.sol)
	// Keys as ISO 3166 Alpha-2 Codes
	mapping(string=>bool) public excludedCountries;


    constructor( IPools _pools, IProposals _proposals, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IStakingConfig _stakingConfig, IRewardsConfig _rewardsConfig, IDAOConfig _daoConfig, IRewardsEmitter _liquidityRewardsEmitter )
		{
		pools = _pools;
		proposals = _proposals;
		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;
		stakingConfig = _stakingConfig;
		rewardsConfig = _rewardsConfig;
		daoConfig = _daoConfig;
        liquidityRewardsEmitter = _liquidityRewardsEmitter;

		// Excluded by default: United States, Canada, United Kingdom, China, India, Pakistan, Russia, Afghanistan, Cuba, Iran, North Korea, Syria, Venezuela
		// Note that the DAO can remove any of these exclusions - or open up access completely to the exchange as it sees fit.
		excludedCountries["US"] = true;
		excludedCountries["CA"] = true;
		excludedCountries["GB"] = true;
		excludedCountries["CN"] = true;
		excludedCountries["IN"] = true;
		excludedCountries["PK"] = true;
		excludedCountries["RU"] = true;
		excludedCountries["AF"] = true;
		excludedCountries["CU"] = true;
		excludedCountries["IR"] = true;
		excludedCountries["KP"] = true;
		excludedCountries["SY"] = true;
		excludedCountries["VE"] = true;
        }


	// Finalize the vote for a parameter ballot (increase, decrease or no_change) for a given parameter
	function _finalizeParameterBallot( uint256 ballotID ) internal
		{
		Ballot memory ballot = proposals.ballotForID(ballotID);

		Vote winningVote = proposals.winningParameterVote(ballotID);

		if ( winningVote == Vote.INCREASE )
			_executeParameterChange( ParameterTypes(ballot.number1), true, poolsConfig, stakingConfig, rewardsConfig, daoConfig );
		else if ( winningVote == Vote.DECREASE )
			_executeParameterChange( ParameterTypes(ballot.number1), false, poolsConfig, stakingConfig, rewardsConfig, daoConfig );

		emit ParameterBallotFinalized(ballotID, winningVote);
		}


	function _executeSetAccessManager( Ballot memory ballot ) internal
		{
		exchangeConfig.setAccessManager( IAccessManager(ballot.address1) );

		emit SetAccessManager(ballot.address1);
		}


	function _executeSetWebsiteURL( Ballot memory ballot ) internal
		{
		websiteURL = ballot.string1;
		emit SetWebsiteURL(ballot.string1);
		}


	function _executeApproval( Ballot memory ballot ) internal
		{
		if ( ballot.ballotType == BallotType.UNWHITELIST_TOKEN )
			{
			// All tokens are paired with both WBTC and WETH so unwhitelist those pools
			poolsConfig.unwhitelistPool( pools, IERC20(ballot.address1), exchangeConfig.salt() );
			poolsConfig.unwhitelistPool( pools, IERC20(ballot.address1), exchangeConfig.weth() );

			// Make sure that the cached arbitrage indicies in PoolStats are updated
			pools.updateArbitrageIndicies();

			emit UnwhitelistToken(IERC20(ballot.address1));
			}

		else if ( ballot.ballotType == BallotType.SEND_SALT )
			{
			// Make sure the contract has the SALT balance before trying to send it.
			// This should not happen but is here just in case - to prevent approved proposals from reverting on finalization.
			if ( exchangeConfig.salt().balanceOf(address(this)) >= ballot.number1 )
				{
				IERC20(exchangeConfig.salt()).safeTransfer( ballot.address1, ballot.number1 );

				emit SaltSent(ballot.address1, ballot.number1);
				}
			}

		else if ( ballot.ballotType == BallotType.CALL_CONTRACT )
			{
			try ICalledContract(ballot.address1).callFromDAO(ballot.number1)
				{
				}
			catch (bytes memory)
				{
				}

			emit ContractCalled(ballot.address1, ballot.number1);
 			}

		else if ( ballot.ballotType == BallotType.INCLUDE_COUNTRY )
			{
			excludedCountries[ ballot.string1 ] = false;

			emit GeoExclusionUpdated(ballot.string1, false, exchangeConfig.accessManager().geoVersion());
			}

		else if ( ballot.ballotType == BallotType.EXCLUDE_COUNTRY )
			{
			excludedCountries[ ballot.string1 ] = true;

			// If the AccessManager doesn't implement excludedCountriesUpdated, this will revert and countries will not be able to be excluded until the AccessManager is working properly.
			exchangeConfig.accessManager().excludedCountriesUpdated();

			emit GeoExclusionUpdated(ballot.string1, true, exchangeConfig.accessManager().geoVersion());
			}

		// Once an initial setAccessManager proposal passes, it automatically starts a second confirmation ballot (to prevent last minute approvals)
		else if ( ballot.ballotType == BallotType.SET_ACCESS_MANAGER )
			proposals.createConfirmationProposal( string.concat("confirm_", ballot.ballotName), BallotType.CONFIRM_SET_ACCESS_MANAGER, ballot.address1, "", ballot.description );

		// Once an initial setWebsiteURL proposal passes, it automatically starts a second confirmation ballot (to prevent last minute approvals)
		else if ( ballot.ballotType == BallotType.SET_WEBSITE_URL )
			proposals.createConfirmationProposal( string.concat("confirm_", ballot.ballotName), BallotType.CONFIRM_SET_WEBSITE_URL, address(0), ballot.string1, ballot.description );

		else if ( ballot.ballotType == BallotType.CONFIRM_SET_ACCESS_MANAGER )
			_executeSetAccessManager( ballot );

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
		}


	// Finalize and execute a token whitelisting ballot.
	// If NO > YES than the proposal is removed immediately (quorum would already have been determined - in canFinalizeBallot as called from finalizeBallot).
	function _finalizeTokenWhitelisting( uint256 ballotID ) internal
		{
		if ( proposals.ballotIsApproved(ballotID ) )
			{
			// The ballot is approved. Any reversions below will allow the ballot to be attemped to be finalized later - as the ballot won't be finalized on reversion.
			Ballot memory ballot = proposals.ballotForID(ballotID);

			uint256 bootstrappingRewards = daoConfig.bootstrappingRewards();

			// Make sure that the DAO contract holds the required amount of SALT for bootstrappingRewards.
			// Twice the bootstrapping rewards are needed (for both the token/WBTC and token/WETH pools)
			uint256 saltBalance = exchangeConfig.salt().balanceOf( address(this) );
			require( saltBalance >= bootstrappingRewards * 2, "Whitelisting is not currently possible due to insufficient bootstrapping rewards" );

			// All tokens are paired with both WBTC and WETH, so whitelist both pairings
			poolsConfig.whitelistPool( pools,  IERC20(ballot.address1), exchangeConfig.salt() );
			poolsConfig.whitelistPool( pools,  IERC20(ballot.address1), exchangeConfig.weth() );

			// Make sure that the cached arbitrage indicies in PoolStats are updated
			pools.updateArbitrageIndicies();

			bytes32 pool1 = PoolUtils._poolID( IERC20(ballot.address1), exchangeConfig.salt() );
			bytes32 pool2 = PoolUtils._poolID( IERC20(ballot.address1), exchangeConfig.weth() );

			// Send the initial bootstrappingRewards to promote initial liquidity on these two newly whitelisted pools
			AddedReward[] memory addedRewards = new AddedReward[](2);
			addedRewards[0] = AddedReward( pool1, bootstrappingRewards );
			addedRewards[1] = AddedReward( pool2, bootstrappingRewards );

			exchangeConfig.salt().approve( address(liquidityRewardsEmitter), bootstrappingRewards * 2 );
			liquidityRewardsEmitter.addSALTRewards( addedRewards );

			emit WhitelistToken(IERC20(ballot.address1));
			}
		}


	// Finalize the vote on a specific ballot.
	// Can be called by anyone, but only actually finalizes the ballot if it can be finalized.
	function finalizeBallot( uint256 ballotID ) external nonReentrant
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

		// Mark the ballot as no longer votable and remove it from the list of open ballots
		proposals.markBallotAsFinalized(ballotID);
		}


	// Remove a ballot from voting which has existed for longer than the DAOConfig.ballotMaximumDuration
	function manuallyRemoveBallot( uint256 ballotID ) external nonReentrant
		{
		Ballot memory ballot = proposals.ballotForID(ballotID);

		require( block.timestamp >= ballot.ballotMaximumEndTime, "The ballot is not yet able to be manually removed" );

		// Mark the ballot as no longer votable and remove it from the list of open ballots
		proposals.markBallotAsFinalized(ballotID);
		}


	// Withdraw deposited tokens in the Pools contract and send them to the caller (the Upkeep contract).
	function withdrawFromDAO( IERC20 token ) external returns (uint256 withdrawnAmount)
		{
		require( msg.sender == address(exchangeConfig.upkeep()), "DAO.withdrawFromDAO is only callable from the Upkeep contract" );

		withdrawnAmount = pools.depositedUserBalance(address(this), token );
		if ( withdrawnAmount <= PoolUtils.DUST )
			return 0;

		pools.withdraw( token, withdrawnAmount );

		token.safeTransfer( msg.sender, withdrawnAmount );

		emit TokensWithdrawn(msg.sender, token, withdrawnAmount);
		}


	// === VIEWS ===

	function countryIsExcluded( string calldata country ) external view returns (bool)
		{
		return excludedCountries[country];
		}
	}