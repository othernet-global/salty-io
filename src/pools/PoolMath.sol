pragma solidity =0.8.22;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/Math.sol";
import "./interfaces/IPools.sol";
import "./PoolUtils.sol";

/*
	=== DERIVATION ===
	// User will zap z0 of token0 and z1 of token1 into the pool
    // Initial reserves: r0 and r1
    // Assuming z0 in excess, determine how much z0 should be swapped to z1 first so that the resulting z0/z1 matches the resulting post-swap reserves ratio so that liquidity can be added with minimal leftover.

    // Initial k
    k = r0 * r1

    // Swap s0 of token0 for s1 of token1
    s1 = r1 - k / (r0 + s0)

    // Substituting k
    s1 = r1 - r0 * r1 / (r0 + s0)

    // Updated reserves ratio after swap
    (r0 + s0) / ( r1 - s1)

    // Adjusted addLiquidity zap amounts after the swap
    a0 = z0 - s0
    a1 = z1 + s1

    // Adjusted addLiquidity amounts need to have the token ratio of the current reserves
    a0 / a1 = (r0 + s0) / ( r1 - s1)

    // Substitute in a0 and a1 from above
    (z0 - s0) / ( z1 + s1) = (r0 + s0) / ( r1 - s1)

    // Substitute
    x = s0         y = s1
    a = r0         b = r1
    c = z0         d = z1

    (c-x)/(d+y) = (a+x)/(b-y)

    // From s1 = r1 - r0 * r1 / (r0 + s0)
    y = b - ab/(a+x)

    // Solve for x
    (c-x)/(d+y) = (a+x)/(b-y)

    // Cross multiply
    (c-x)(b-y) = (a+x)(d+y)

    // Multiply binomials on both sides
    bc - cy - bx + xy = ad + ay + dx + xy

    // Cancel xy both sides
    bc - cy - bx = ad + ay + dx

    // Multiply both sides by -1
    - bc + cy + bx = - ad - ay - dx

    // Gather x and y on the left
    bx + dx + ay + cy = bc - ad

    // Factor x and y
    x(b+d) + y(a+c) = bc - ad

    // Substitute y = b - ab/(a+x)
    x(b+d) + b(a+c) - ab(a+c)/(a+x) = bc - ad

    // Multiply by (a+x)
    x(b+d)(a+x) + b(a+c)(a+x) - ab(a+c) = (bc - ad)(a+x)

    // Multiply all binomials
    x(ab+bx+ad+dx) + b(aa+ax+ac+cx) - aab - abc = abc+bcx-aad-adx

    // Distribute x and b
    abx+bxx+adx+dxx + aab+abx+abc+bcx - aab - abc = abc+bcx-aad-adx

    // Cancel abc (on left), bcx, aab
    abx + bxx + adx + dxx + abx = abc - aad - adx

    // Gather x on the left
    bxx + dxx + abx + abx + adx + adx = abc - aad

    // Factor xx and x
    xx(b+d) + x(2ab + 2ad) = abc - aad

    // Quadratic equation
    xx(b+d) + x(2ab + 2ad) + (aad-abc) = 0

    // Factor out 2a
    xx(b+d) + x(2a)(b+d) + (aad-abc) = 0

    // Divide by (b+d)
    xx + x(2a) + (aad-abc)/(b+d) = 0

    xxA + xB + C = 0

    A = 1
    B = 2a
    C = a(ad - bc)/(b+d)

    // Substitute back
    a = r0         b = r1
    c = z0         d = z1

    A = 1
    B = 2r0
    C = r0(r0z1 - r1z0)/(r1 + z1)

    x = [-B + sqrt(B^2 - 4AC)] / 2A
*/

library PoolMath
	{
	// Determine the most significant bit of a non-zero number
    function _mostSignificantBit(uint256 x) internal pure returns (uint256 msb)
    	{
        if (x >= 2**128) { x >>= 128; msb += 128; }
        if (x >= 2**64) { x >>= 64; msb += 64; }
        if (x >= 2**32) { x >>= 32; msb += 32; }
        if (x >= 2**16) { x >>= 16; msb += 16; }
        if (x >= 2**8) { x >>= 8; msb += 8; }
        if (x >= 2**4) { x >>= 4; msb += 4; }
        if (x >= 2**2) { x >>= 2; msb += 2; }
        if (x >= 2**1) { x >>= 1; msb += 1; }
	    }


	// Determine the maximum msb across the given values
	function _maximumMSB( uint256 r0, uint256 r1, uint256 z0, uint256 z1 ) internal pure returns (uint256 msb)
		{
		msb = _mostSignificantBit(r0);

		uint256 m = _mostSignificantBit(r1);
		if ( m > msb )
			msb = m;

		m = _mostSignificantBit(z0);
		if ( m > msb )
			msb = m;

		m = _mostSignificantBit(z1);
		if ( m > msb )
			msb = m;
		}


	// Given initial reserves, and that the user wants to zap specified token amounts into the pool as liquidity,
	// determine how much of token0 needs to be swapped to token1 such that the liquidity added has the same proportion as the reserves in the pool after that swap.
	// Assumes that token0 is in excess (in regards to the current reserve ratio).
    function _zapSwapAmount( uint256 reserve0, uint256 reserve1, uint256 zapAmount0, uint256 zapAmount1 ) internal pure returns (uint256 swapAmount)
    	{
    	uint256 maximumMSB = _maximumMSB( reserve0, reserve1, zapAmount0, zapAmount1);

		uint256 shift = 0;

    	// Assumes the largest number has more than 80 bits - but if not then shifts zero effectively as a straight assignment.
    	// C will be calculated as: C = r0 * ( r1 * z0 - r0 * z1 ) / ( r1 + z1 );
    	// Multiplying three 80 bit numbers will yield 240 bits - within the 256 bit limit.
		if ( maximumMSB > 80 )
			shift = maximumMSB - 80;

    	// Normalize the inputs to 80 bits.
    	uint256 r0 = reserve0 >> shift;
		uint256 r1 = reserve1 >> shift;
		uint256 z0 = zapAmount0 >> shift;
		uint256 z1 = zapAmount1 >> shift;

		// In order to swap and zap, require that the reduced precision reserves and one of the zapAmounts exceed DUST.
		// Otherwise their value was too small and was crushed by the above precision reduction and we should just return swapAmounts of zero so that default addLiquidity will be attempted without a preceding swap.
        if ( r0 < PoolUtils.DUST)
        	return 0;

        if ( r1 < PoolUtils.DUST)
        	return 0;

        if ( z0 < PoolUtils.DUST)
        if ( z1 < PoolUtils.DUST)
        	return 0;

        // Components of the quadratic formula mentioned in the initial comment block: x = [-B + sqrt(B^2 - 4AC)] / 2A
		uint256 A = 1;
        uint256 B = 2 * r0;

		// Here for reference
//        uint256 C = r0 * ( r0 * z1 - r1 * z0 ) / ( r1 + z1 );
//        uint256 discriminant = B * B - 4 * A * C;

		// Negate C (from above) and add instead of subtract.
		// r1 * z0 guaranteed to be greater than r0 * z1 per the conditional check in _determineZapSwapAmount
        uint256 C = r0 * ( r1 * z0 - r0 * z1 ) / ( r1 + z1 );
        uint256 discriminant = B * B + 4 * A * C;

        // Compute the square root of the discriminant.
        uint256 sqrtDiscriminant = Math.sqrt(discriminant);

		// Safety check: make sure B is not greater than sqrtDiscriminant
		if ( B > sqrtDiscriminant )
			return 0;

        // Only use the positive sqrt of the discriminant from: x = (-B +/- sqrtDiscriminant) / 2A
		swapAmount = ( sqrtDiscriminant - B ) / ( 2 * A );

		// Denormalize from the 80 bit representation
		swapAmount <<= shift;
    	}


	// Determine how much of either token needs to be swapped to give them a ratio equivalent to the reserves.
	// If (0,0) is returned it signifies that no swap should be done before the addLiquidity.
	function _determineZapSwapAmount( uint256 reserveA, uint256 reserveB, uint256 zapAmountA, uint256 zapAmountB ) internal pure returns (uint256 swapAmountA, uint256 swapAmountB )
		{
		// zapAmountA / zapAmountB exceeds the ratio of reserveA / reserveB? - meaning too much zapAmountA
		if ( zapAmountA * reserveB > reserveA * zapAmountB )
			(swapAmountA, swapAmountB) = (_zapSwapAmount( reserveA, reserveB, zapAmountA, zapAmountB ), 0);

		// zapAmountA / zapAmountB is less than the ratio of reserveA / reserveB? - meaning too much zapAmountB
		if ( zapAmountA * reserveB < reserveA * zapAmountB )
			(swapAmountA, swapAmountB) = (0, _zapSwapAmount( reserveB, reserveA, zapAmountB, zapAmountA ));

		// Ensure we are not swapping more than was specified for zapping
		if ( ( swapAmountA > zapAmountA ) || ( swapAmountB > zapAmountB ) )
			return (0, 0);

		return (swapAmountA, swapAmountB);
		}
	}
