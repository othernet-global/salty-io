// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IExchangeConfig.sol";
import "./interfaces/IAirdrop.sol";


// The Airdrop contract keeps track of users who qualify for the Salty.IO Airdrop.
// The amount of awarded SALT for each user will be claimable over 52 weeks (starting from when allowClaiming() is called)

contract Airdrop is IAirdrop, ReentrancyGuard
    {
	using SafeERC20 for ISalt;

    uint256 constant VESTING_PERIOD = 52 weeks;

	IExchangeConfig immutable public exchangeConfig;
    ISalt immutable public salt;

	// The timestamp when allowClaiming() was called
	uint256 public claimingStartTimestamp;

	// The claimable airdrop amount for each user
	mapping (address=>uint256) airdropPerUser;

	// The amount already claimed by each user
	mapping (address=>uint256) claimedPerUser;


	constructor( IExchangeConfig _exchangeConfig )
		{
		exchangeConfig = _exchangeConfig;

		salt = _exchangeConfig.salt();
		}


	// Authorize the wallet as being able to claim a specific amount of the airdrop.
	// The BootstrapBallot would have already confirmed the user is authorized to receive the specified saltAmount.
    function authorizeWallet( address wallet, uint256 saltAmount ) external
    	{
    	require( msg.sender == address(exchangeConfig.initialDistribution().bootstrapBallot()), "Only the BootstrapBallot can call Airdrop.authorizeWallet" );
    	require( claimingStartTimestamp == 0, "Cannot authorize after claiming is allowed" );
    	require( airdropPerUser[wallet] == 0, "Wallet already authorized" );

		airdropPerUser[wallet] = saltAmount;
    	}


	// Called to signify that users are able to start claiming their airdrop
    function allowClaiming() external
    	{
    	require( msg.sender == address(exchangeConfig.initialDistribution().bootstrapBallot()), "Only the BootstrapBallot can call Airdrop.allowClaiming" );
    	require( claimingStartTimestamp == 0, "Claiming is already allowed" );

		claimingStartTimestamp = block.timestamp;
    	}


	// Allow the user to claim up to the vested amount they are entitled to
    function claim() external nonReentrant
    	{
  		uint256 claimableSALT = claimableAmount(msg.sender);

    	require( claimableSALT != 0, "User has no claimable airdrop at this time" );

		// Send SALT to the user
		salt.safeTransfer( msg.sender, claimableSALT);

		// Remember the amount that was claimed by the user
		claimedPerUser[msg.sender] += claimableSALT;
    	}


    // === VIEWS ===

	// Whether or not claiming is allowed
	function claimingAllowed() public view returns (bool)
		{
		return claimingStartTimestamp != 0;
		}


	// The amount that the user has already claimed
	function claimedByUser( address wallet) public view returns (uint256)
		{
		return claimedPerUser[wallet];
		}


	// The amount of SALT that is currently claimable for the user
    function claimableAmount(address wallet) public view returns (uint256)
    	{
    	// Claiming not allowed yet?
    	if ( claimingStartTimestamp == 0 )
    		return 0;

    	// Look up the airdrop amount for the user
		uint256 airdropAmount = airdropPerUser[wallet];
		if ( airdropAmount == 0 )
			return 0;

		uint256 timeElapsed = block.timestamp - claimingStartTimestamp;
		uint256 vestedAmount = ( airdropAmount * timeElapsed) / VESTING_PERIOD;

		// Don't exceed the airdropAmount
		if ( vestedAmount > airdropAmount )
			vestedAmount = airdropAmount;

		// Users can claim the vested amount they are entitled to minus the amount they have already claimed
		return vestedAmount - claimedPerUser[wallet];
    	}


    // The totral airdrop that the user will receive
    function airdropForUser( address wallet ) public view returns (uint256)
    	{
    	return airdropPerUser[wallet];
    	}
	}