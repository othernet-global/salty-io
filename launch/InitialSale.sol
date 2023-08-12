// SPDX-License-Identifier: BUSL 1.1
pragma solidity =0.8.21;

import "../openzeppelin/token/ERC20/ERC20.sol";
import "../openzeppelin/access/Ownable.sol";
import "../openzeppelin/security/ReentrancyGuard.sol";


contract InitialSale is Ownable, ReentrancyGuard
    {
    ERC20 public salt;

	uint256 public endTime;
	uint256 public totalDeposits;
	uint256 public totalClaimableSALT;

	bool public usersCanClaim;

	mapping(address => uint256) public userDeposits;
	mapping(address => bool) public userClaimed;

	constructor( address _salt )
		{
		salt = ERC20( _salt );

//		endTime = block.timestamp + 1 hours; // debug
		endTime = block.timestamp + 7 days; // live
        }


	// ===== ONLY OWNER =====

	function provideClaimableSALT( uint256 _totalClaimableSALT ) public onlyOwner
		{
		require( _totalClaimableSALT != 0, "Must provide more than zero SALT" );

		totalClaimableSALT = _totalClaimableSALT;

		// Deposit the SALT which will be claimable by users after the sale is over
		require( salt.transferFrom( msg.sender, address(this), totalClaimableSALT ), "Transfer failed" );
		}


	// After the sale is over, the owner can withdraw the deposited MATIC.
	// The MATIC will be paired with 15 million SALT to form the initial SALT/MATIC liquidity
	function withdrawDepositedMATIC() public onlyOwner
		{
    	address payable wallet = payable( msg.sender );

        require( block.timestamp >= endTime, "The sale has not ended yet" );

		// Withdraw the MATIC to the owner wallet
    	uint256 maticBalance = address(this).balance;

		(bool status, ) = wallet.call{ value: maticBalance }( "" );
		require(status, "Withdraw failed");
		}


	function allowClaiming() public onlyOwner
		{
		require( totalClaimableSALT > 0, "SALT hasn't been added yet" );
        require( block.timestamp >= endTime, "The sale has not ended yet" );

		usersCanClaim = true;
		}



	// ===== PUBLIC  =====

	// Users can deposit MATIC as long as the sale is still active
    function depositMATIC() public payable nonReentrant
    	{
    	address wallet = msg.sender;
		uint256 depositAmount = msg.value;

        require( block.timestamp < endTime, "Sale is no longer active" );
    	require( depositAmount > 0, "Deposit amount must be more than zero" );

        userDeposits[wallet] += depositAmount;
        totalDeposits += depositAmount;
   		}


	// Users who have participated in the sale can withdraw their share of the SALT
	// once userCanClaim=true
    function claimSALT() public nonReentrant
    	{
    	address wallet = msg.sender;

		require( usersCanClaim, "Users cannot claim yet" );
        require( ! userClaimed[wallet], "User has already claimed SALT" );

		uint256 claimableSALT = userShareSALT( wallet );

		require( salt.transfer( wallet, claimableSALT ), "Transfer failed" );

		userClaimed[wallet] = true;
   		}


	// ===== VIEW =====

	function timeRemaining() public view returns (uint256)
		{
		if ( endTime <= block.timestamp )
			return 0;

		return endTime - block.timestamp;
		}


	function userDepositedAmount( address wallet ) public view returns (uint256)
		{
		return userDeposits[wallet];
		}


	function userShareSALT( address wallet ) public view returns (uint256)
		{
		if ( totalDeposits == 0 )
			return 0;

		return ( totalClaimableSALT * userDeposits[wallet] ) / totalDeposits;
		}


	function userAlreadyClaimed( address wallet ) public view returns (bool)
		{
		return userClaimed[wallet];
		}
	}

