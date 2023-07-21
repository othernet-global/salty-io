//// SPDX-License-Identifier: BSL 1.1
//pragma solidity =0.8.20;
//
//import "forge-std/Test.sol";
//import "../uniswap/core/interfaces/IUniswapV2Factory.sol";
//import "../uniswap/core/interfaces/IUniswapV2Pair.sol";
//import "../uniswap/periphery/interfaces/IUniswapV2Router02.sol";
//import "../openzeppelin/token/ERC20/IERC20.sol";
//import "./TestERC20.sol";
//
//
//contract TestArbitrageSearch is Test
//	{
//	// Swapping resources
//	IUniswapV2Router02 public constant _saltyRouter = IUniswapV2Router02(address(0x901fC84C5c46Df5E0AB2c6ad48825e3B1B0295a6));
//    IUniswapV2Factory public _factory = IUniswapV2Factory(_saltyRouter.factory());
//
//	// User wallets for testing
//    address public constant alice = address(0x1111);
//    address public constant bob = address(0x2222);
//    address public constant charlie = address(0x3333);
//
//	IERC20 public tokenA;
//	IERC20 public tokenB;
//	IERC20 public tokenC;
//	IERC20 public tokenD;
//
//
//	constructor()
//		{
//		}
//
//
//    function setUp() public
//    	{
//    	tokenA = new TestERC20( 18 );
//    	tokenB = new TestERC20( 18 );
//    	tokenC = new TestERC20( 18 );
//    	tokenD = new TestERC20( 18 );
//
//    	tokenA.approve( address(_saltyRouter), type(uint256).max);
//    	tokenB.approve( address(_saltyRouter), type(uint256).max);
//    	tokenC.approve( address(_saltyRouter), type(uint256).max);
//    	tokenD.approve( address(_saltyRouter), type(uint256).max);
//
//    	_saltyRouter.addLiquidity( address(tokenA), address(tokenB), 1000 ether, 1000 ether, 0, 0, address(this), block.timestamp );
//    	_saltyRouter.addLiquidity( address(tokenB), address(tokenC), 1000 ether, 1000 ether, 0, 0, address(this), block.timestamp );
//    	_saltyRouter.addLiquidity( address(tokenC), address(tokenD), 1000 ether, 1000 ether, 0, 0, address(this), block.timestamp );
//    	}
//
//
//    function testGasUsageSwap() public
//    	{
//        address[] memory path = new address[](2);
//    	path[0] = address(tokenA);
//		path[1] = address(tokenB);
//
//    	_saltyRouter.swapExactTokensForTokens( 1000, 0, path, address(this), block.timestamp );
//    	}
//
//
//    function testGasUsageArb() public
//    	{
//    	testGasUsageSwap();
//
//        address[] memory path = new address[](4);
//    	path[0] = address(tokenA);
//		path[1] = address(tokenB);
//		path[2] = address(tokenC);
//		path[3] = address(tokenD);
//
//    	_saltyRouter.swapExactTokensForTokens( 1000, 0, path, address(this), block.timestamp );
//
//    	tokenD.transfer( alice, 1 );
//    	}
//
//    function testOptimizationGas() public pure
//    	{
//		uint256 r0 = 100;
//		uint256 r1 = 200;
//		uint256 r2 = 300;
//
//		uint256 s0 = 1000;
//		uint256 s1 = 2000;
//		uint256 s2 = 3000;
//
//		uint256 k0 = r0 * s0;
//		uint256 k1 = r1 * s1;
//		uint256 k2 = r2 * s2;
//
//		uint256 x = 100;
//		uint256 y = 0;
//		for( uint256 i = 0; i < 10; i++ )
//			{
//			x = x + 100;
//			y = s2 - k2 / ( r2 + s1 - k1 / ( r1 + s0 - k0 / ( r0 + x ) ) );
//			}
//    	}
//    }
//
