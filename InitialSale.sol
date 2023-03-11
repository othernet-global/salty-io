// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

import "./openzeppelin/token/ERC20/ERC20.sol";
import "./openzeppelin/access/Ownable2Step.sol";
import "./openzeppelin/security/ReentrancyGuard.sol";


contract InitialSale is Ownable2Step, ReentrancyGuard
    {
    ERC20 usdc;
    ERC20 salt;

	uint256 public endTime;
	uint256 public totalDeposits;
	uint256 public totalClaimableSALT;

	bool public usersCanClaim = false;

	mapping(address => uint256) public userDeposits;
	mapping(address => bool) public userClaimed;


	constructor( address _usdc, address _salt, uint256 _durationInHours )
		{
		usdc = ERC20( _usdc );
		salt = ERC20( _salt );

		endTime = block.timestamp + _durationInHours * 1 hours;
        }


	// ===== ONLY OWNER =====

	function provideClaimableSALT( uint256 _totalClaimableSALT ) public onlyOwner
		{
		totalClaimableSALT = _totalClaimableSALT;

		// Deposit the SALT which will be claimable by users after the sale is over
		salt.transferFrom( msg.sender, address(this), totalClaimableSALT );
		}


	// After the sale is over, the owner can withdraw the deposited USDC.
	// The USDC will be paired with 15 million SALT to form the initial SALT/USDC liquidity
	function withdrawDepositedUSDC() public onlyOwner
		{
    	address wallet = msg.sender;

        require( block.timestamp >= endTime, "The sale hasn't ended yet" );

		// Withdraw the USDC to the owner wallet
    	uint256 usdcBalance = usdc.balanceOf( address(this) );
    	usdc.transfer( wallet, usdcBalance );
		}


	function allowClaiming() public onlyOwner
		{
        require( block.timestamp >= endTime, "The sale hasn't ended yet" );

		usersCanClaim = true;
		}



	// ===== PUBLIC  =====

	// Users can deposit USDC as long as the sale is still active
    function depositUSDC( uint256 usdcAmount ) public nonReentrant
    	{
    	address wallet = msg.sender;

        require( block.timestamp < endTime, "Sale is no longer active" );

        usdc.transferFrom( wallet, address(this), usdcAmount );
        userDeposits[wallet] += usdcAmount;

        totalDeposits += usdcAmount;
   		}


	// Users who have participated in the sale can withdraw their share of the SALT
	// once userCanClaim=true
    function claimSALT() public nonReentrant
    	{
    	address wallet = msg.sender;

		require( usersCanClaim, "Users cannot claim yet" );
        require( block.timestamp >= endTime, "The sale hasn't ended yet" );
        require( ! userClaimed[wallet], "User has already claimed SALT" );

		uint256 claimableSALT = userShareSALT( wallet );

		salt.transfer( wallet, claimableSALT );

		userClaimed[wallet] = true;
   		}


	// ===== VIEW =====

	function timeRemaining() public view returns (uint256)
		{
		if ( endTime <= block.timestamp )
			return 0;

		return endTime - block.timestamp;
		}


	function userDepositedUSDC( address wallet ) public view returns (uint256)
		{
		return userDeposits[wallet];
		}


	function userShareSALT( address wallet ) public view returns (uint256)
		{
		return ( totalClaimableSALT * userDeposits[wallet] ) / totalDeposits;
		}


	function userAlreadyClaimed( address wallet ) public view returns (bool)
		{
		return userClaimed[wallet];
		}
	}

