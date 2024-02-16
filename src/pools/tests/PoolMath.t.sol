// SPDX-License-Identifier: Unlicensed
pragma solidity =0.8.22;

import "../../pools/PoolMath.sol";
import { console, Test } from "forge-std/Test.sol";

contract BugPoolMath is Test
{
    function test_poolMath() public view {
        uint256 reserveA = 1500000000;
        uint256 reserveB = 2000000000 ether;
        uint256 zapAmountA = 150;
        uint256 zapAmountB = 100 ether;

        (uint256 swapAmountA, uint256 swapAmountB) = PoolMath._determineZapSwapAmount(reserveA, reserveB, zapAmountA, zapAmountB);
        console.log("swapAmountA = %s, swapAmountB = %s", swapAmountA, swapAmountB);
    }
}