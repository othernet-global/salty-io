// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "../../openzeppelin/token/ERC20/IERC20.sol";


enum Vote { INCREASE, DECREASE, NO_CHANGE, YES, NO }
enum BallotType { PARAMETER, WHITELIST_TOKEN, UNWHITELIST_TOKEN, SEND_SALT, CALL_CONTRACT, INCLUDE_COUNTRY, EXCLUDE_COUNTRY, SET_CONTRACT, SET_WEBSITE_URL, CONFIRM_SET_CONTRACT, CONFIRM_SET_WEBSITE_URL }

struct UserVote
	{
	Vote vote;
	uint256 votingPower;				// Voting power at the time the vote was cast
	}

struct Ballot
	{
	uint256 ballotID;
	bool ballotIsLive;

	BallotType ballotType;
	string ballotName;
	address address1;
	uint256 number1;
	string string1;
	string string2;

	// The earliest timestamp at which a ballot can end. Can be open longer if the quorum has not yet been reached for instance.
	uint256 ballotMinimumEndTime;
	}


interface IProposals
	{
	function createConfirmationProposal( string calldata ballotName, BallotType ballotType, address address1, string memory string1 ) external;
	function markBallotAsFinalized( uint256 ballotID ) external;

	function proposeParameterBallot( uint256 parameterType ) external;
	function proposeTokenWhitelisting( IERC20 token, string calldata tokenIconURL, string calldata tokenDescription ) external;
	function proposeTokenUnwhitelisting( IERC20 token, string calldata tokenIconURL, string calldata tokenDescription ) external;
	function proposeSendSALT( address wallet, uint256 amount ) external;
	function proposeCallContract( address contractAddress, uint256 number ) external;
	function proposeCountryInclusion( string calldata country ) external;
	function proposeCountryExclusion( string calldata country ) external;
	function proposeSetContractAddress( string calldata contractName, address newAddress ) external;
	function proposeWebsiteUpdate( string calldata newWebsiteURL ) external;
	function castVote( uint256 ballotID, Vote vote ) external;

	// Views
	function nextBallotID() external returns (uint256);
	function openBallotsByName( string calldata name ) external returns (uint256);
	function lastUserVoteForBallot( uint256 ballotID, address user ) external view returns (UserVote memory);
	function votesCastForBallot( uint256 ballotID, Vote vote ) external view returns (uint256);

	function ballotForID( uint256 ballotID ) external view returns (Ballot calldata);
	function requiredQuorumForBallotType( BallotType ballotType ) external view returns (uint256);
	function totalVotesCastForBallot( uint256 ballotID ) external view returns (uint256);
	function ballotIsApproved( uint256 ballotID ) external view returns (bool);
	function winningParameterVote( uint256 ballotID ) external view returns (Vote);
	function canFinalizeBallot( uint256 ballotID ) external view returns (bool);
	function numberOfOpenBallotsForTokenWhitelisting() external view returns (uint256);
	function tokenWhitelistingBallotWithTheMostVotes() external view returns (uint256);
	}