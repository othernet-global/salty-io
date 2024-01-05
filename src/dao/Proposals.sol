// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "../pools/interfaces/IPoolsConfig.sol";
import "../staking/interfaces/IStaking.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IDAOConfig.sol";
import "./interfaces/IProposals.sol";
import "./interfaces/IDAO.sol";
import "../pools/PoolUtils.sol";


// Allows SALT stakers to propose and vote on various types of ballots such as parameter changes, token whitelisting/unwhitelisting, sending tokens, calling contracts, and updating website URLs.
// Ensures ballot uniqueness, tracks and validates user voting power, enforces quorums, and provides a mechanism for users to alter votes.

contract Proposals is IProposals, ReentrancyGuard
    {
    event ProposalCreated(uint256 indexed ballotID, BallotType ballotType, string ballotName);
    event BallotFinalized(uint256 indexed ballotID);
    event VoteCast(address indexed voter, uint256 indexed ballotID, Vote vote, uint256 votingPower);

	using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    IStaking immutable public staking;
    IExchangeConfig immutable public exchangeConfig;
    IPoolsConfig immutable public poolsConfig;
    IDAOConfig immutable public daoConfig;
    ISalt immutable public salt;

	// Mapping from ballotName to a currently open ballotID (zero if none).
	// Used to check for existing ballots by name so as to not allow duplicate ballots to be created.
	mapping(string=>uint256) public openBallotsByName;

	// Maps ballotID to the corresponding Ballot
	mapping(uint256=>Ballot) public ballots;
	uint256 public nextBallotID = 1;

	// All of the ballotIDs that are currently open for voting
	EnumerableSet.UintSet private _allOpenBallots;

	// The ballotIDs of the tokens currently being proposed for whitelisting
	EnumerableSet.UintSet private _openBallotsForTokenWhitelisting;

	// The number of votes cast for a given ballot by Vote type
	mapping(uint256=>mapping(Vote=>uint256)) private _votesCastForBallot;

	// The last vote cast by a user for a given ballot.
	// Allows users to change their vote - so that the previous vote can be undone before casting the new vote.
	mapping(uint256=>mapping(address=>UserVote)) private _lastUserVoteForBallot;

	// Which users currently have active proposals
	// Useful for checking that users are only able to create one active proposal at a time (to discourage spam proposals).
	mapping(address=>bool) private _userHasActiveProposal;

	// Which users proposed which ballots.
	// Useful when a ballot is finalized - so that the user that proposed it can have their _usersWithActiveProposals status cleared
	mapping(uint256=>address) private _usersThatProposedBallots;

	// The time at which the first proposal can be made (45 days after deployment).
	// This is to allow some time for users to start staking - as some percent of stake is required to propose ballots and if the total amount staked.
	uint256 immutable firstPossibleProposalTimestamp = block.timestamp + 45 days;


    constructor( IStaking _staking, IExchangeConfig _exchangeConfig, IPoolsConfig _poolsConfig, IDAOConfig _daoConfig )
		{
		staking = _staking;
		exchangeConfig = _exchangeConfig;
		poolsConfig = _poolsConfig;
		daoConfig = _daoConfig;

		salt = exchangeConfig.salt();
        }


	function _possiblyCreateProposal( string memory ballotName, BallotType ballotType, address address1, uint256 number1, string memory string1, string memory string2 ) internal returns (uint256 ballotID)
		{
		require( block.timestamp >= firstPossibleProposalTimestamp, "Cannot propose ballots within the first 45 days of deployment" );

		// The DAO can create confirmation proposals which won't have the below requirements
		if ( msg.sender != address(exchangeConfig.dao() ) )
			{
			// Make sure that the sender has the minimum amount of xSALT required to make the proposal
			uint256 totalStaked = staking.totalShares(PoolUtils.STAKED_SALT);
			uint256 requiredXSalt = ( totalStaked * daoConfig.requiredProposalPercentStakeTimes1000() ) / ( 100 * 1000 );

			require( requiredXSalt > 0, "requiredXSalt cannot be zero" );

			uint256 userXSalt = staking.userShareForPool( msg.sender, PoolUtils.STAKED_SALT );
			require( userXSalt >= requiredXSalt, "Sender does not have enough xSALT to make the proposal" );

			// Make sure that the user doesn't already have an active proposal
			require( ! _userHasActiveProposal[msg.sender], "Users can only have one active proposal at a time" );
			}

		// Make sure that a proposal of the same name is not already open for the ballot
		require( openBallotsByName[ballotName] == 0, "Cannot create a proposal similar to a ballot that is still open" );
		require( openBallotsByName[ string.concat(ballotName, "_confirm")] == 0, "Cannot create a proposal for a ballot with a secondary confirmation" );

		uint256 ballotMinimumEndTime = block.timestamp + daoConfig.ballotMinimumDuration();

		// Add the new Ballot to storage
		ballotID = nextBallotID++;
		ballots[ballotID] = Ballot( ballotID, true, ballotType, ballotName, address1, number1, string1, string2, ballotMinimumEndTime );
		openBallotsByName[ballotName] = ballotID;
		_allOpenBallots.add( ballotID );

		// Remember that the user made a proposal
		_userHasActiveProposal[msg.sender] = true;
		_usersThatProposedBallots[ballotID] = msg.sender;

		emit ProposalCreated(ballotID, ballotType, ballotName);
		}


	// Create a confirmation proposal from the DAO
	function createConfirmationProposal( string calldata ballotName, BallotType ballotType, address address1, string calldata string1, string calldata description ) external returns (uint256 ballotID)
		{
		require( msg.sender == address(exchangeConfig.dao()), "Only the DAO can create a confirmation proposal" );

		return _possiblyCreateProposal( ballotName, ballotType, address1, 0, string1, description );
		}


	function markBallotAsFinalized( uint256 ballotID ) external nonReentrant
		{
		require( msg.sender == address(exchangeConfig.dao()), "Only the DAO can mark a ballot as finalized" );

		Ballot storage ballot = ballots[ballotID];

		// Remove finalized whitelist token ballots from the list of open whitelisting proposals
		if ( ballot.ballotType == BallotType.WHITELIST_TOKEN )
			_openBallotsForTokenWhitelisting.remove( ballotID );

		// Remove from the list of all open ballots
		_allOpenBallots.remove( ballotID );

		ballot.ballotIsLive = false;

		// Indicate that the user who posted the proposal no longer has an active proposal
		address userThatPostedBallot = _usersThatProposedBallots[ballotID];
		_userHasActiveProposal[userThatPostedBallot] = false;

		delete openBallotsByName[ballot.ballotName];

		emit BallotFinalized(ballotID);
		}


	function proposeParameterBallot( uint256 parameterType, string calldata description ) external nonReentrant returns (uint256 ballotID)
		{
		string memory ballotName = string.concat("parameter:", Strings.toString(parameterType) );
		return _possiblyCreateProposal( ballotName, BallotType.PARAMETER, address(0), parameterType, "", description );
		}


	function proposeTokenWhitelisting( IERC20 token, string calldata tokenIconURL, string calldata description ) external nonReentrant returns (uint256 _ballotID)
		{
		require( address(token) != address(0), "token cannot be address(0)" );
		require( token.totalSupply() < type(uint112).max, "Token supply cannot exceed uint112.max" ); // 5 quadrillion max supply with 18 decimals of precision

		require( _openBallotsForTokenWhitelisting.length() < daoConfig.maxPendingTokensForWhitelisting(), "The maximum number of token whitelisting proposals are already pending" );
		require( poolsConfig.numberOfWhitelistedPools() < poolsConfig.maximumWhitelistedPools(), "Maximum number of whitelisted pools already reached" );
		require( ! poolsConfig.tokenHasBeenWhitelisted(token, exchangeConfig.wbtc(), exchangeConfig.weth()), "The token has already been whitelisted" );

		string memory ballotName = string.concat("whitelist:", Strings.toHexString(address(token)) );

		uint256 ballotID = _possiblyCreateProposal( ballotName, BallotType.WHITELIST_TOKEN, address(token), 0, tokenIconURL, description );
		_openBallotsForTokenWhitelisting.add( ballotID );

		return ballotID;
		}


	function proposeTokenUnwhitelisting( IERC20 token, string calldata tokenIconURL, string calldata description ) external nonReentrant returns (uint256 ballotID)
		{
		require( poolsConfig.tokenHasBeenWhitelisted(token, exchangeConfig.wbtc(), exchangeConfig.weth()), "Can only unwhitelist a whitelisted token" );
		require( address(token) != address(exchangeConfig.wbtc()), "Cannot unwhitelist WBTC" );
		require( address(token) != address(exchangeConfig.weth()), "Cannot unwhitelist WETH" );
		require( address(token) != address(exchangeConfig.dai()), "Cannot unwhitelist DAI" );
		require( address(token) != address(exchangeConfig.usds()), "Cannot unwhitelist USDS" );
		require( address(token) != address(exchangeConfig.salt()), "Cannot unwhitelist SALT" );

		string memory ballotName = string.concat("unwhitelist:", Strings.toHexString(address(token)) );
		return _possiblyCreateProposal( ballotName, BallotType.UNWHITELIST_TOKEN, address(token), 0, tokenIconURL, description );
		}


	// Proposes sending a specified amount of SALT to a wallet or contract.
	// Only one sendSALT Ballot can be open at a time and the sending limit is 5% of the current SALT balance of the DAO.
	function proposeSendSALT( address wallet, uint256 amount, string calldata description ) external nonReentrant returns (uint256 ballotID)
		{
		require( wallet != address(0), "Cannot send SALT to address(0)" );

		// Limit to 5% of current balance
		uint256 balance = exchangeConfig.salt().balanceOf( address(exchangeConfig.dao()) );
		uint256 maxSendable = balance * 5 / 100;
		require( amount <= maxSendable, "Cannot send more than 5% of the DAO SALT balance" );

		// This ballotName is not unique for the receiving wallet and enforces the restriction of one sendSALT ballot at a time.
		// If more receivers are necessary at once, a splitter can be used.
		string memory ballotName = "sendSALT";
		return _possiblyCreateProposal( ballotName, BallotType.SEND_SALT, wallet, amount, "", description );
		}


	// Proposes calling the callFromDAO(uint256) function on an arbitrary contract.
	function proposeCallContract( address contractAddress, uint256 number, string calldata description ) external nonReentrant returns (uint256 ballotID)
		{
		require( contractAddress != address(0), "Contract address cannot be address(0)" );

		string memory ballotName = string.concat("callContract:", Strings.toHexString(address(contractAddress)) );
		return _possiblyCreateProposal( ballotName, BallotType.CALL_CONTRACT, contractAddress, number, description, "" );
		}


	function proposeCountryInclusion( string calldata country, string calldata description ) external nonReentrant returns (uint256 ballotID)
		{
		require( bytes(country).length == 2, "Country must be an ISO 3166 Alpha-2 Code" );

		string memory ballotName = string.concat("include:", country );
		return _possiblyCreateProposal( ballotName, BallotType.INCLUDE_COUNTRY, address(0), 0, country, description );
		}


	function proposeCountryExclusion( string calldata country, string calldata description ) external nonReentrant returns (uint256 ballotID)
		{
		require( bytes(country).length == 2, "Country must be an ISO 3166 Alpha-2 Code" );

		string memory ballotName = string.concat("exclude:", country );
		return _possiblyCreateProposal( ballotName, BallotType.EXCLUDE_COUNTRY, address(0), 0, country, description );
		}


	function proposeSetContractAddress( string calldata contractName, address newAddress, string calldata description ) external nonReentrant returns (uint256 ballotID)
		{
		require( newAddress != address(0), "Proposed address cannot be address(0)" );

		string memory ballotName = string.concat("setContract:", contractName );
		return _possiblyCreateProposal( ballotName, BallotType.SET_CONTRACT, newAddress, 0, "", description );
		}


	function proposeWebsiteUpdate( string calldata newWebsiteURL, string calldata description ) external nonReentrant returns (uint256 ballotID)
		{
		require( keccak256(abi.encodePacked(newWebsiteURL)) != keccak256(abi.encodePacked("")), "newWebsiteURL cannot be empty" );

		string memory ballotName = string.concat("setURL:", newWebsiteURL );
		return _possiblyCreateProposal( ballotName, BallotType.SET_WEBSITE_URL, address(0), 0, newWebsiteURL, description );
		}


	// Cast a vote on an open ballot
	function castVote( uint256 ballotID, Vote vote ) external nonReentrant
		{
		Ballot memory ballot = ballots[ballotID];

		// Require that the ballot is actually live
		require( ballot.ballotIsLive, "The specified ballot is not open for voting" );

		// Make sure that the vote type is valid for the given ballot
		if ( ballot.ballotType == BallotType.PARAMETER )
			require( (vote == Vote.INCREASE) || (vote == Vote.DECREASE) || (vote == Vote.NO_CHANGE), "Invalid VoteType for Parameter Ballot" );
		else // If a Ballot is not a Parameter Ballot, it is an Approval ballot
			require( (vote == Vote.YES) || (vote == Vote.NO), "Invalid VoteType for Approval Ballot" );

		// Make sure that the user has voting power before proceeding.
		// Voting power is equal to their userShare of STAKED_SALT.
		// If the user changes their stake after voting they will have to recast their vote.

		uint256 userVotingPower = staking.userShareForPool( msg.sender, PoolUtils.STAKED_SALT );
		require( userVotingPower > 0, "Staked SALT required to vote" );

		// Remove any previous votes made by the user on the ballot
		UserVote memory lastVote = _lastUserVoteForBallot[ballotID][msg.sender];

		// Undo the last vote?
		if ( lastVote.votingPower > 0 )
			_votesCastForBallot[ballotID][lastVote.vote] -= lastVote.votingPower;

		// Update the votes cast for the ballot with the user's current voting power
		_votesCastForBallot[ballotID][vote] += userVotingPower;

		// Remember how the user voted in case they change their vote later
		_lastUserVoteForBallot[ballotID][msg.sender] = UserVote( vote, userVotingPower );

		emit VoteCast(msg.sender, ballotID, vote, userVotingPower);
		}


	// === VIEWS ===
	function ballotForID( uint256 ballotID ) external view returns (Ballot memory)
		{
		return ballots[ballotID];
		}


	function lastUserVoteForBallot( uint256 ballotID, address user ) external view returns (UserVote memory)
		{
		return _lastUserVoteForBallot[ballotID][user];
		}


	function votesCastForBallot( uint256 ballotID, Vote vote ) external view returns (uint256)
		{
		return _votesCastForBallot[ballotID][vote];
		}


	// The required quorum is normally a default 10% of the amount of SALT staked.
	// There is though a minimum of 0.50% of SALT.totalSupply (in the case that the amount of staked SALT is low - at launch for instance).
	function requiredQuorumForBallotType( BallotType ballotType ) public view returns (uint256 requiredQuorum)
		{
		// The quorum will be specified as a percentage of the total amount of SALT staked
		uint256 totalStaked = staking.totalShares( PoolUtils.STAKED_SALT );
		require( totalStaked != 0, "SALT staked cannot be zero to determine quorum" );

		if ( ballotType == BallotType.PARAMETER )
			requiredQuorum = ( 1 * totalStaked * daoConfig.baseBallotQuorumPercentTimes1000()) / ( 100 * 1000 );
		else if ( ( ballotType == BallotType.WHITELIST_TOKEN ) || ( ballotType == BallotType.UNWHITELIST_TOKEN ) )
			requiredQuorum = ( 2 * totalStaked * daoConfig.baseBallotQuorumPercentTimes1000()) / ( 100 * 1000 );
		else
			// All other ballot types require 3x multiple of the baseQuorum
			requiredQuorum = ( 3 * totalStaked * daoConfig.baseBallotQuorumPercentTimes1000()) / ( 100 * 1000 );

		// Make sure that the requiredQuorum is at least 0.50% of the total SALT supply.
		// Circulating supply after the first 45 days of emissions will be about 3 million - so this would require about 16% of the circulating
		// SALT to be staked and voting to pass a proposal (including whitelisting) 45 days after deployment..
		uint256 totalSupply = ERC20(address(exchangeConfig.salt())).totalSupply();
		uint256 minimumQuorum = totalSupply * 5 / 1000;

		if ( requiredQuorum < minimumQuorum )
			requiredQuorum = minimumQuorum;
		}


	function totalVotesCastForBallot( uint256 ballotID ) public view returns (uint256)
		{
		mapping(Vote=>uint256) storage votes = _votesCastForBallot[ballotID];

		Ballot memory ballot = ballots[ballotID];
		if ( ballot.ballotType == BallotType.PARAMETER )
			return votes[Vote.INCREASE] + votes[Vote.DECREASE] + votes[Vote.NO_CHANGE];
		else
			return votes[Vote.YES] + votes[Vote.NO];
		}


	// Assumes that the quorum has been checked elsewhere
	function ballotIsApproved( uint256 ballotID ) external view returns (bool)
		{
		mapping(Vote=>uint256) storage votes = _votesCastForBallot[ballotID];

		return votes[Vote.YES] > votes[Vote.NO];
		}


	// Assumes that the quorum has been checked elsewhere
	function winningParameterVote( uint256 ballotID ) external view returns (Vote)
		{
		mapping(Vote=>uint256) storage votes = _votesCastForBallot[ballotID];

		uint256 increaseTotal = votes[Vote.INCREASE];
		uint256 decreaseTotal = votes[Vote.DECREASE];
		uint256 noChangeTotal = votes[Vote.NO_CHANGE];

		if ( increaseTotal > decreaseTotal )
		if ( increaseTotal > noChangeTotal )
			return Vote.INCREASE;

		if ( decreaseTotal > increaseTotal )
		if ( decreaseTotal > noChangeTotal )
			return Vote.DECREASE;

		return Vote.NO_CHANGE;
		}


	// Checks that ballot is live, and minimumEndTime and quorum have both been reached.
	function canFinalizeBallot( uint256 ballotID ) external view returns (bool)
		{
        Ballot memory ballot = ballots[ballotID];
        if ( ! ballot.ballotIsLive )
        	return false;

        // Check that the minimum duration has passed
        if (block.timestamp < ballot.ballotMinimumEndTime )
            return false;

        // Check that the required quorum has been reached
        if ( totalVotesCastForBallot(ballotID) < requiredQuorumForBallotType( ballot.ballotType ))
            return false;

        return true;
	    }


	function openBallots() external view returns (uint256[] memory)
		{
		return _allOpenBallots.values();
		}


	function openBallotsForTokenWhitelisting() external view returns (uint256[] memory)
		{
		return _openBallotsForTokenWhitelisting.values();
		}


	// Returns the ballotID of the whitelisting ballot that currently has the most yes votes
	// Requires that the quorum has been reached and that the number of yes votes is greater than the number no votes
	function tokenWhitelistingBallotWithTheMostVotes() external view returns (uint256)
		{
		uint256 quorum = requiredQuorumForBallotType( BallotType.WHITELIST_TOKEN);

		uint256 bestID = 0;
		uint256 mostYes = 0;
		for( uint256 i = 0; i < _openBallotsForTokenWhitelisting.length(); i++ )
			{
			uint256 ballotID = _openBallotsForTokenWhitelisting.at(i);
			uint256 yesTotal = _votesCastForBallot[ballotID][Vote.YES];
			uint256 noTotal = _votesCastForBallot[ballotID][Vote.NO];

			if ( (yesTotal + noTotal) >= quorum ) // Make sure that quorum has been reached
			if ( yesTotal > noTotal )  // Make sure the token vote is favorable
			if ( yesTotal > mostYes )  // Make sure these are the most yes votes seen
				{
				bestID = ballotID;
				mostYes = yesTotal;
				}
			}

		return bestID;
		}


	function userHasActiveProposal( address user ) external view returns (bool)
		{
		return _userHasActiveProposal[user];
		}
	}