//// SPDX-License-Identifier: BSL 1.1
//pragma solidity ^0.8.12;
//
//import "../openzeppelin/utils/structs/EnumerableSet.sol";
//import "../openzeppelin/token/ERC20/utils/SafeERC20.sol";
//import "../staking/interfaces/IStakingConfig.sol";
//import "../staking/interfaces/IStakingRewards.sol";
//import "../interfaces/IExchangeConfig.sol";
//import "./interfaces/IDAOConfig.sol";
//import "../openzeppelin/security/ReentrancyGuard.sol";
//import "./interfaces/IProposals.sol";
//import "./Parameters.sol";
//import "../uniswap/core/interfaces/IUniswapV2Factory.sol";
//
//
//contract Proposals is IProposals, Parameters, ReentrancyGuard
//    {
//	struct UserVote
//		{
//		Vote vote;
//		uint256 votingPower;
//		}
//
//
//	using SafeERC20 for IERC20;
//    using EnumerableSet for EnumerableSet.UintSet;
//
//	// @notice A special pool that represents staked SALT that is not associated with any particular liquidity pool.
//	IUniswapV2Pair public constant STAKED_SALT = IUniswapV2Pair(address(0));
//
//    IStakingConfig public stakingConfig;
//    IDAOConfig public daoConfig;
//    IExchangeConfig public exchangeConfig;
//    IStakingRewards public staking;
//	IUniswapV2Factory public factory;
//
//
//	// Mapping from ballotName to the currently open ballotID (zero if none)
//	mapping(string=>uint256) public openBallotsByName;
//
//	// Maps ballotID to the corresponding Ballot
//	mapping(uint256=>Ballot) public ballots;
//	uint256 public nextBallotID = 1;
//
//	// The ballotIDs of the tokens currently being proposed for whitelisting
//	EnumerableSet.UintSet private _openBallotsForTokenWhitelisting;
//
//	// The current vote totals for a given ballot (cast for all options)
//	mapping(uint256=>uint256) public ballotVoteTotals;
//
//	// The number of votes cast for each proposal option on a given ballot
//	mapping(uint256=>mapping(Vote=>uint256)) public votesCastForBallot;
//
//	// The last vote cast by a user for a given ballot
//	// This is here so that if the user changes their vote for the ballet - then the vote can be undone
//	mapping(uint256=>mapping(address=>UserVote)) public lastUserVoteForBallot;
//
//
//    constructor( IStakingConfig _stakingConfig, IDAOConfig _daoConfig, IExchangeConfig _exchangeConfig, IStakingRewards _staking, IUniswapV2Factory _factory )
//		{
//		require( address(_stakingConfig) != address(0), "_stakingConfig cannot be address(0)" );
//		require( address(_daoConfig) != address(0), "_daoConfig cannot be address(0)" );
//		require( address(_exchangeConfig) != address(0), "_exchangeConfig cannot be address(0)" );
//		require( address(_staking) != address(0), "_staking cannot be address(0)" );
//		require( address(_factory) != address(0), "_factory cannot be address(0)" );
//
//		stakingConfig = _stakingConfig;
//		daoConfig = _daoConfig;
//		exchangeConfig = _exchangeConfig;
//		staking = _staking;
//		factory = _factory;
//        }
//
//
//	function _markBallotAsFinalized( Ballot storage ballot ) internal
//		{
//		ballot.ballotIsLive = false;
//
//		delete openBallotsByName[ballot.ballotName];
//		}
//
//
//	function _possiblyCreateProposal( string memory ballotName, BallotType ballotType, address address1, uint256 number1, string memory string1, string memory string2, uint256 proposalCost ) internal returns (uint256 ballotID)
//		{
//		require( exchangeConfig.walletHasAccess(msg.sender), "Sending wallet does not have exchange access" );
//
//		// Make sure that a proposal is not already open for the ballot
//		require( openBallotsByName[ballotName] == 0, "Cannot create a proposal for an open ballot" );
//		require( openBallotsByName[string.concat(ballotName, "_confirm")] == 0, "Cannot create a proposal for a ballot that is already being confirmed" );
//
//		uint256 ballotMinimumEndTime = block.timestamp + daoConfig.ballotDuration();
//
//		// Keep track of the new ballot
//		ballotID = nextBallotID;
//		ballots[ballotID] = Ballot( nextBallotID, true, ballotType, ballotName, address1, number1, string1, string2, ballotMinimumEndTime );
//		openBallotsByName[ballotName] = ballotID;
//
//		nextBallotID++;
//
//		// Send the proposalFee (in USDS) from the sender to the POL_Optimizer for later creation of Protocol Owned Liquidity
//		if ( proposalCost > 0 )
//			{
//			IERC20 usds = IERC20(exchangeConfig.usds());
//
//			require( usds.allowance(msg.sender, address(this)) >= proposalCost, "Insufficient allowance to create proposal" );
//			require( usds.balanceOf(msg.sender) >= proposalCost, "Sender does not have USDS for proposal cost" );
//			usds.safeTransferFrom( msg.sender, address(exchangeConfig.optimizer()), proposalCost );
//			}
//		}
//
//
//	// ballotName expected as "parameterName"
//	function proposeParameterBallot( string memory ballotName, uint256 parameterType ) public nonReentrant
//		{
//		_possiblyCreateProposal( ballotName, BallotType.PARAMETER, address(0), parameterType, "", "", 1 * daoConfig.baseProposalCost() );
//		}
//
//
//	// ballotName expected as "whitelist:tokenAddress"
//	function proposeTokenWhitelisting( string memory ballotName, address token, string memory tokenIconURL, string memory tokenDescription ) public nonReentrant
//		{
// don't allow address(0)
//		require( _openBallotsForTokenWhitelisting.length() < daoConfig.maxPendingTokensForWhitelisting(), "The maximum number of token whitelisting proposals are already pending" );
//		require( ! tokenHasBeenWhitelisted(token), "The token has already been whitelisted" );
//		require( stakingConfig.numberOfWhitelistedPools() < stakingConfig.maximumWhitelistedPools(), "Maximum number of whitelisted pools already reached" );
//
//
//		uint256 ballotID = _possiblyCreateProposal( ballotName, BallotType.WHITELIST_TOKEN, token, 0, tokenIconURL, tokenDescription, 2 * daoConfig.baseProposalCost() );
//		_openBallotsForTokenWhitelisting.add( ballotID );
//		}
//
//
//	// ballotName expected as "unwhitelist:tokenAddress"
//	function proposeTokenUnwhitelisting( string memory ballotName, address token, string memory tokenIconURL, string memory tokenDescription ) public nonReentrant
//		{
//		require( tokenHasBeenWhitelisted(token), "Can only unwhitelist a whitelisted token" );
//		require( token != address(exchangeConfig.wbtc()), "Cannot unwhitelist WBTC" );
//		require( token != address(exchangeConfig.weth()), "Cannot unwhitelist WETH" );
//		require( token != address(exchangeConfig.usdc()), "Cannot unwhitelist USDC" );
//		require( token != address(exchangeConfig.usds()), "Cannot unwhitelist USDS" );
//
//		_possiblyCreateProposal( ballotName, BallotType.UNWHITELIST_TOKEN, token, 0, tokenIconURL, tokenDescription, 2 * daoConfig.baseProposalCost() );
//		}
//
//
//	// ballotName expected as "sendSALT:wallet"
//	// Proposes sending a specified amount of SALT to a wallet or contract
//	function proposeSendSALT( string memory ballotName, address wallet, uint256 amount ) public nonReentrant
//		{
//		// Limit to 5% of balance
//		uint256 balance = stakingConfig.salt().balanceOf( address(this) );
//		uint256 maxSendable = balance * 5 / 100;
//		require( amount < maxSendable, "Cannot send more than 5% of the existing balance" );
//
//		_possiblyCreateProposal( ballotName, BallotType.SEND_SALT, wallet, amount, "", "", 3 * daoConfig.baseProposalCost() );
//		}
//
//
//	// ballotName expected as "callContract:address"
//	// Proposes calling the callFromDAO(uint256) method on an arbitrary contract.
//	function proposeCallContract( string memory ballotName, address contractAddress, uint256 number ) public nonReentrant
//		{
//		_possiblyCreateProposal( ballotName, BallotType.CALL_CONTRACT, contractAddress, number, "", "", 3 * daoConfig.baseProposalCost() );
//		}
//
//
//	// ballotName expected as "include:countryCode"
//	function proposeCountryInclusion( string memory ballotName, string memory country ) public nonReentrant
//		{
//		_possiblyCreateProposal( ballotName, BallotType.INCLUDE_COUNTRY, address(0), 0, country, "", 5 * daoConfig.baseProposalCost() );
//		}
//
//
//	// ballotName expected as "exclude:countryCode"
//	function proposeCountryExclusion( string memory ballotName, string memory country ) public nonReentrant
//		{
//		_possiblyCreateProposal( ballotName, BallotType.EXCLUDE_COUNTRY, address(0), 0, country, "", 5 * daoConfig.baseProposalCost() );
//		}
//
//
//	// ballotName expected as "setContract:contractName"
//	function proposeSetContractAddress( string memory ballotName, address newAddress ) public nonReentrant
//		{
//		require( newAddress != address(0), "Proposed address cannot be address(0)" );
//		_possiblyCreateProposal( ballotName, BallotType.SET_CONTRACT, newAddress, 0, "", "", 10 * daoConfig.baseProposalCost() );
//		}
//
//
//	// ballotName expected as "setURL:setWebsiteURL"
//	function proposeWebsiteUpdate( string memory ballotName, string memory newWebsiteURL ) public nonReentrant
//		{
//		_possiblyCreateProposal( ballotName, BallotType.SET_WEBSITE_URL, address(0), 0, newWebsiteURL, "", 10 * daoConfig.baseProposalCost() );
//		}
//
//
//	// Cast a vote on an open ballot
//	function castVote( uint256 ballotID, Vote vote ) public nonReentrant
//		{
//		require( exchangeConfig.walletHasAccess(msg.sender), "Sending wallet does not have exchange access" );
//
//		Ballot memory ballot = ballots[ballotID];
//
//		// Require that the ballot is actually live
//		require( ballot.ballotIsLive, "The specified ballot is not open for voting" );
//
//		// Make sure that the vote type is valid for the given ballot
//		if ( ballot.ballotType == BallotType.PARAMETER )
//			require( (vote == Vote.INCREASE) || (vote == Vote.DECREASE) || (vote == Vote.NO_CHANGE), "Invalid VoteType for Parameter Ballot" );
//		else
//			require( (vote == Vote.YES) || (vote == Vote.NO), "Invalid VoteType for Approval Ballot" );
//
//		// Make sure that the user has voting power before proceeding.
//		// Voting power is equal to the userShare of SALT staked.
//		// If the user changes their stake after voting they will have to recast their vote.
//
//		uint256 userVotingPower = staking.userShareInfoForPool( msg.sender, STAKED_SALT ).userShare;
//		require( userVotingPower > 0, "User does not have any voting power" );
//
//		// Remove any previous votes made by the user on the ballot
//		UserVote memory lastVote = lastUserVoteForBallot[ballotID][msg.sender];
//		uint256 lastVotingPower = lastVote.votingPower;
//
//		if ( lastVotingPower > 0 )
//			{
//			// Undo the last vote
//			ballotVoteTotals[ballotID] -= lastVotingPower;
//			votesCastForBallot[ballotID][lastVote.vote] -= lastVotingPower;
//			}
//
//		// Update the vote total for the ballot with the user's current voting power
//		ballotVoteTotals[ballotID] += userVotingPower;
//		votesCastForBallot[ballotID][vote] += userVotingPower;
//
//		// Remember how the user voted in case they change their vote later
//		lastUserVoteForBallot[ballotID][msg.sender] = UserVote( vote, userVotingPower );
//		}
//
//
//	// === VIEWS ===
//	function ballotForID( uint256 ballotID ) public view returns (Ballot memory)
//		{
//		return ballots[ballotID];
//		}
//
//
//	function requiredQuorumForBallotType( BallotType ballotType ) public view returns (uint256)
//		{
//		// The quorum will be specified as a percentage of the total saltSupply
//		uint256 saltSupply = stakingConfig.salt().totalSupply();
//		require( saltSupply != 0, "SALT supply cannot be zero to determine quorum" );
//
//		if ( ballotType == BallotType.PARAMETER )
//			return ( 1 * saltSupply * daoConfig.baseBallotQuorumPercentSupplyTimes1000()) / ( 100 * 1000 );
//		if ( ( ballotType == BallotType.WHITELIST_TOKEN ) || ( ballotType == BallotType.UNWHITELIST_TOKEN ) )
//			return ( 2 * saltSupply * daoConfig.baseBallotQuorumPercentSupplyTimes1000()) / ( 100 * 1000 );
//
//		// All other ballot types require 3x multiple of the baseQuorum
//		return ( 3 * saltSupply * daoConfig.baseBallotQuorumPercentSupplyTimes1000()) / ( 100 * 1000 );
//		}
//
//
//	function totalVotesCastForBallot( uint256 ballotID ) public view returns (uint256)
//		{
//		return ballotVoteTotals[ballotID];
//		}
//
//
//	function canFinalizeBallot( uint256 ballotID ) public view returns (bool)
//		{
//        Ballot memory ballot = ballots[ballotID];
//        if ( ! ballot.ballotIsLive )
//        	return false;
//
//        // Check that the minimum duration has passed
//        if (ballot.ballotMinimumEndTime > block.timestamp)
//            return false;
//
//        // Check that the required quorum has been reached
//        if ( ballotVoteTotals[ballotID] < requiredQuorumForBallotType( ballot.ballotType ))
//            return false;
//
//        return true;
//	    }
//
//
//	function numberOfOpenBallotsForTokenWhitelisting() public view returns (uint256)
//		{
//		return _openBallotsForTokenWhitelisting.length();
//		}
//
//
//
//	// Returns the ballotID of the whitelisting ballot that currently has the most yes votes
//	// Requires that the quorum has been reached and that the numbe rof yes votes is greater than the number no votes
//	function tokenWhitelistingBallotWithTheMostVotes() public view returns (uint256)
//		{
//		uint256 bestID = 0;
//		uint256 mostYes = 0;
//
//		uint256 quorum = requiredQuorumForBallotType( BallotType.WHITELIST_TOKEN);
//
//		for( uint256 i = 0; i < _openBallotsForTokenWhitelisting.length(); i++ )
//			{
//			uint256 ballotID = _openBallotsForTokenWhitelisting.at(i);
//			uint256 yesTotal = votesCastForBallot[ballotID][Vote.YES];
//			uint256 noTotal = votesCastForBallot[ballotID][Vote.NO];
//
//			if ( ballotVoteTotals[ballotID] >= quorum ) // Make sure that quorum has been reached
//			if ( yesTotal > noTotal )  // Make sure the token vote is favorable
//			if ( yesTotal > mostYes )  // Make sure these are the most yes votes seen
//				{
//				bestID = ballotID;
//				mostYes = yesTotal;
//				}
//			}
//
//		return bestID;
//		}
//
//
//	function tokenHasBeenWhitelisted( address token ) public view returns (bool)
//		{
//		// See if the token has been whitelisted with either WBTC or WETH, as all whitelisted tokens are pooled with both WBTC and WETH
//		if ( stakingConfig.isValidPool( IUniswapV2Pair( factory.getPair(token, exchangeConfig.wbtc())) ))
//			return true;
//		if ( stakingConfig.isValidPool( IUniswapV2Pair( factory.getPair(token, exchangeConfig.weth())) ))
//			return true;
//
//		return false;
//		}
//	}