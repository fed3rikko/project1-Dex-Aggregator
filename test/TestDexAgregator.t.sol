// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/DexAggregator.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// --------------------
/// MOCK TOKEN
/// --------------------
contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

/// --------------------
/// MOCK V2 ROUTER
/// --------------------
contract MockV2Router {
    // V2 is worse: 1 -> 2
    function getAmountsOut(uint256 amountIn, address[] calldata)
        external
        pure
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn * 2;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] calldata,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn * 2;

        return amounts;
    }
}

/// --------------------
/// MOCK V3 QUOTER
/// --------------------
contract MockV3Quoter {
    function quoteExactInputSingle(
        IQuoterV2.QuoteExactInputSingleParams calldata params
    )
        external
        pure
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        return (
            params.amountIn * 3,
            0,
            0,
            0
        );
    }
}

/// --------------------
/// MOCK V3 ROUTER
/// --------------------
contract MockV3Router {
    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams calldata params
    ) external returns (uint256 amountOut) {
        // same rule: 3x output
        return params.amountIn * 3;
    }
}

/// --------------------
/// TESTS
/// --------------------
contract DexAggregatorTest is Test {
    MockERC20 tokenIn;
    MockERC20 tokenOut;

    MockV2Router v2;
    MockV3Router v3Router;
    MockV3Quoter v3Quoter;

    DexAggregator agg;

    address user = address(0x123);

    function setUp() public {
        tokenIn = new MockERC20("IN", "IN");
        tokenOut = new MockERC20("OUT", "OUT");

        v2 = new MockV2Router();
        v3Router = new MockV3Router();
        v3Quoter = new MockV3Quoter();

        agg = new DexAggregator(
            address(v2),
            address(v3Router),
            address(v3Quoter),
            address(this)
        );

        tokenIn.mint(user, 100 ether);
    }

    // -----------------------------
    // 1. V2 QUOTE
    // -----------------------------
    function testV2Quote() public {
        uint256 out = agg.quoteV2(address(tokenIn), address(tokenOut), 1 ether);

        assertEq(out, 2 ether);
    }

    // -----------------------------
    // 2. V3 IS BETTER → selected
    // -----------------------------
    function testBestQuoteSelectsV3() public {
        DexAggregator.Quote memory q =
            agg.getBestQuote(address(tokenIn), address(tokenOut), 1 ether);

        assertTrue(q.useV3);
        assertEq(q.amountOut, 3 ether);
    }

    // -----------------------------
    // 3. SWAP uses V3 path
    // -----------------------------
    function testSwapUsesV3() public {
        vm.startPrank(user);

        tokenIn.approve(address(agg), 1 ether);

        uint256 out = agg.swap(
            address(tokenIn),
            address(tokenOut),
            1 ether,
            2 ether,
            block.timestamp + 1000
        );

        assertEq(out, 3 ether);
    }

    // -----------------------------
    // 4. SLIPPAGE FAIL
    // -----------------------------
    function testSlippageRevert() public {
        vm.startPrank(user);

        tokenIn.approve(address(agg), 1 ether);

        vm.expectRevert("Slippage");
        agg.swap(
            address(tokenIn),
            address(tokenOut),
            1 ether,
            10 ether, // too strict
            block.timestamp + 1000
        );
    }
}


/// --------------------
/// MOCK V3 QUOTER WITH DIFFERENT OUTPUTS PER FEE TIER
/// --------------------
contract MockV3QuoterByFeeTier {
    function quoteExactInputSingle(
        IQuoterV2.QuoteExactInputSingleParams calldata params
    )
        external
        pure
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {
        if (params.fee == 500) {
            amountOut = params.amountIn * 2;
        } else if (params.fee == 3000) {
            amountOut = params.amountIn * 4;
        } else if (params.fee == 10000) {
            amountOut = params.amountIn * 3;
        }

        return (amountOut, 0, 0, 0);
    }
}


contract DexAggregatorFeeTierTest is Test {
    MockERC20 tokenIn;
    MockERC20 tokenOut;

    MockV2Router v2;
    MockV3Router v3Router;
    MockV3QuoterByFeeTier v3Quoter;

    DexAggregator agg;

    function setUp() public {
        tokenIn = new MockERC20("IN", "IN");
        tokenOut = new MockERC20("OUT", "OUT");

        v2 = new MockV2Router();
        v3Router = new MockV3Router();
        v3Quoter = new MockV3QuoterByFeeTier();

        agg = new DexAggregator(
            address(v2),
            address(v3Router),
            address(v3Quoter),
            address(this)
        );
    }

    function testQuoteV3BestSelectsBestFeeTier() public {
        (uint256 amountOut, uint24 fee) = agg.quoteV3Best(
            address(tokenIn),
            address(tokenOut),
            1 ether
        );

        console.log("Best V3 amountOut =", amountOut);
        console.log("Best V3 fee =", fee);

        // Fee tier 3000 returns the best quote in this mock
        assertEq(amountOut, 4 ether);
        assertEq(fee, 3000);
    }
}