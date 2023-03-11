// SPDX-License-Identifier: BSL 1.1
pragma solidity =0.8.17;

// This contract basically creates a line of succession for control over the team membership.
// It specifies the active OpenZeppelin PaymentSplitter so that funds can be claimed by active team members.
// If the active PaymentSplitter is replaced, the old one can still be claimed from.

// There is only one activeManager at a time.
// The team members are ranked so that any team member could become manager - but
// only if higher ranked members allow them to.
// The idea is that that will only happen if the higher ranked members are no longer present.

contract TeamManager
    {
    // The amount of time for an attempted promotion to finish.
    // If a higher ranked member denies the promotion during this time, then the promotion is denied.
    // If the promotion completes, then the member who attempted it can become activeManager.
    uint256 constant PROMOTION_DURATION = 30 days;

    address public activeManager;

	// The originalOwner has the power to regain the position of activeManager at any point.
	// This would only be used in emegencies if the existing activeManager wallet was compromised.
	address public originalOwner;

	address[] public members;
	mapping(address => bool) public memberExists;

	mapping(address => uint256) public ranks;

	// The times at which promotions would be complete and users could become the activeManager
	mapping(address => uint256 ) promotionCompleteTimes;

	address paymentSplitter;


    modifier onlyManager
        {
        require( msg.sender == activeManager );
        _;
        }


	constructor( address _paymentSplitter )
		{
		originalOwner = msg.sender;
		activeManager = msg.sender;

		// Set up the initial PaymentSplitter
		paymentSplitter = _paymentSplitter;
        }


	// ===== ORIGINAL OWNER =====

	function emergencyBecomeManager() public
		{
        require( msg.sender == originalOwner, "Only callable by the original owner" );

        activeManager = originalOwner;
		}


	// ===== ONLY MANAGER =====

	function setMemberRank( address wallet, uint256 rank ) public onlyManager
		{
		// Only add the member once
		if ( ! memberExists[wallet] )
			{
			members.push( wallet);
			memberExists[wallet] = true;
			}

		// Update the rank
		ranks[wallet] = rank;
		}


	function setPaymentSplitter( address _paymentSplitter ) public onlyManager
		{
		paymentSplitter = _paymentSplitter;
		}


	// ===== MEMBERS =====

	function denyAllPromotions() public
		{
		address wallet = msg.sender;
		require( memberExists[wallet], "Have to be a member to deny promotions" );

		uint256 rank = ranks[wallet];
		require( rank != 0, "Can't deny with a rank of zero" );

		for( uint256 i = 0; i < members.length; i++ )
			{
			// Deny the promotion of any member with a lower rank
			address member = members[i];
			uint256 memberRank = ranks[member];

			if ( rank > memberRank )
				promotionCompleteTimes[member] = 0;  // denied!
			}
		}


	// Starts the promotion process
	function attemptPromotion() public
		{
		address wallet = msg.sender;
		require( memberExists[wallet], "Have to be a member to start promotion" );

		promotionCompleteTimes[wallet] = block.timestamp + PROMOTION_DURATION;
		}


	// Only valid after the promotion process has finished
	function becomeManager() public
		{
		address wallet = msg.sender;

		require( memberExists[wallet], "Have to be a member to become manager" );
		require( promotionCompleteTimes[wallet] != 0, "No active attempted promotion" );
		require( block.timestamp >= promotionCompleteTimes[wallet], "Promotion has not completed yet" );

		activeManager = wallet; // promotion happens! R.I.P. Daniel! 😄
		}


	// ===== VIEWS =====
	function activePaymentSplitter() public view returns (address)
		{
		return paymentSplitter;
		}
	}

