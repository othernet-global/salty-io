// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.12;

import "./IDAOConfig.sol";
import "../../staking/interfaces/IStakingConfig.sol";
import "../../staking/interfaces/IStakingRewards.sol";


enum Vote { INCREASE, DECREASE, NO_CHANGE, YES, NO }

enum BallotType { PARAMETER, WHITELIST_TOKEN, UNWHITELIST_TOKEN, SEND_SALT, CALL_CONTRACT, INCLUDE_COUNTRY, EXCLUDE_COUNTRY, SET_CONTRACT, SET_WEBSITE_URL, CONFIRM_SET_CONTRACT, CONFIRM_SET_WEBSITE_URL }

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
	function proposeParameterBallot( string memory ballotName, uint256 parameterType ) external;
	function proposeTokenWhitelisting( string memory ballotName, address token, string memory tokenIconURL, string calldata tokenDescription ) external;
	function proposeTokenUnwhitelisting( string memory ballotName, address token, string memory tokenIconURL, string calldata tokenDescription ) external;
	function proposeSendSALT( string memory ballotName, address wallet, uint256 amount ) external;
	function proposeCallContract( string memory ballotName, address contractAddress, uint256 number ) external;
	function proposeCountryInclusion( string memory ballotName, string calldata country ) external;
	function proposeCountryExclusion( string memory ballotName, string calldata country ) external;
	function proposeSetContractAddress( string memory ballotName, address newAddress ) external;
	function proposeWebsiteUpdate( string memory ballotName, string memory newWebsiteURL ) external;

	function castVote( uint256 ballotID, Vote vote ) external;
	function ballotForID( uint256 ballotID ) external view returns (Ballot memory);
	function requiredQuorumForBallotType( BallotType ballotType ) external view returns (uint256);
	function totalVotesCastForBallot( uint256 ballotID ) external view returns (uint256);
	function canFinalizeBallot( uint256 ballotID ) external view returns (bool);
	function numberOfOpenBallotsForTokenWhitelisting() external view returns (uint256);
	function tokenWhitelistingBallotWithTheMostVotes() external view returns (uint256);

	function daoConfig() external view returns (IDAOConfig);
	function stakingConfig() external view returns (IStakingConfig);
	function staking() external view returns (IStakingRewards);
	function tokenHasBeenWhitelisted( address token ) external returns (bool);
	}