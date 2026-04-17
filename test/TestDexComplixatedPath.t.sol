// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/DexAggregatorV2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract MockERC20 is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

contract MockV2Router {
    function getAmountsOut(uint256 amountIn, address[] calldata)
        external
        pure
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external pure returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }
}

contract MockSmartQuoter {
    function quoteExactInputSingle(
        IQuoterV2.QuoteExactInputSingleParams calldata params
    )
        external
        pure
        returns (
            uint256 amountOut,
            uint160,
            uint32,
            uint256
        )
    {
        // TOKEN_A -> TOKEN_C direct = 2x
        if (
            params.tokenIn == address(11) &&
            params.tokenOut == address(33)
        ) {
            amountOut = params.amountIn * 2;
        }
        // TOKEN_A -> TOKEN_B = 3x
        else if (
            params.tokenIn == address(11) &&
            params.tokenOut == address(22)
        ) {
            amountOut = params.amountIn * 3;
        }
        // TOKEN_B -> TOKEN_C = 2x
        else if (
            params.tokenIn == address(22) &&
            params.tokenOut == address(33)
        ) {
            amountOut = params.amountIn * 2;
        }

        return (amountOut, 0, 0, 0);
    }
}

contract MockV3Router {
    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams calldata params
    ) external pure returns (uint256 amountOut) {
        if (
            params.tokenIn == address(11) &&
            params.tokenOut == address(33)
        ) {
            return params.amountIn * 2;
        }

        if (
            params.tokenIn == address(11) &&
            params.tokenOut == address(22)
        ) {
            return params.amountIn * 3;
        }

        if (
            params.tokenIn == address(22) &&
            params.tokenOut == address(33)
        ) {
            return params.amountIn * 2;
        }

        return 0;
    }
}

contract DexAggregatorV2RouteTest is Test {
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockERC20 tokenC;

    MockV2Router v2;
    MockV3Router v3Router;
    MockSmartQuoter v3Quoter;

    DexAggregatorV2 agg;

    function setUp() public {
        tokenA = new MockERC20("TOKEN_A", "A");
        tokenB = new MockERC20("TOKEN_B", "B");
        tokenC = new MockERC20("TOKEN_C", "C");

        v2 = new MockV2Router();
        v3Router = new MockV3Router();
        v3Quoter = new MockSmartQuoter();

        address[] memory routing = new address[](1);
        routing[0] = address(22);

        agg = new DexAggregatorV2(
            address(v2),
            address(v3Router),
            address(v3Quoter),
            address(this),
            routing
        );
    }

    function testBestSequenceQuoteSelectsIntermediateRoute() public {
        DexAggregatorV2.Route memory route = agg.getBestSequenceQuote(
            address(11),
            address(33),
            1 ether
        );

        assertEq(route.amountOut, 6 ether);
        assertEq(route.hops.length, 2);

        assertEq(route.hops[0].tokenIn, address(11));
        assertEq(route.hops[0].tokenOut, address(22));

        assertEq(route.hops[1].tokenIn, address(22));
        assertEq(route.hops[1].tokenOut, address(33));
    }
}



contract MockERC20Four is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

contract MockV2RouterFour {
    function getAmountsOut(uint256 amountIn, address[] calldata)
        external
        pure
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external pure returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }
}

contract MockSmartQuoterFour {
    function quoteExactInputSingle(
        IQuoterV2.QuoteExactInputSingleParams calldata params
    )
        external
        pure
        returns (
            uint256 amountOut,
            uint160,
            uint32,
            uint256
        )
    {
        address A = address(11);
        address B = address(22);
        address C = address(33);
        address D = address(44);

        // direct A -> D
        if (params.tokenIn == A && params.tokenOut == D) {
            amountOut = params.amountIn * 2;
        }

        // A -> B -> D path
        else if (params.tokenIn == A && params.tokenOut == B) {
            amountOut = params.amountIn * 2;
        } else if (params.tokenIn == B && params.tokenOut == D) {
            amountOut = params.amountIn * 2;
        }

        // A -> C -> D path
        else if (params.tokenIn == A && params.tokenOut == C) {
            amountOut = params.amountIn * 3;
        } else if (params.tokenIn == C && params.tokenOut == D) {
            amountOut = params.amountIn * 2;
        }

        // BEST PATH: A -> B -> C -> D
        else if (params.tokenIn == B && params.tokenOut == C) {
            amountOut = params.amountIn * 3;
        }

        // weaker reverse / irrelevant edges
        else if (params.tokenIn == C && params.tokenOut == B) {
            amountOut = params.amountIn;
        } else if (params.tokenIn == B && params.tokenOut == A) {
            amountOut = params.amountIn;
        } else if (params.tokenIn == D && params.tokenOut == C) {
            amountOut = params.amountIn;
        }

        return (amountOut, 0, 0, 0);
    }
}

contract MockV3RouterFour {
    function exactInputSingle(
        ISwapRouter.ExactInputSingleParams calldata params
    ) external pure returns (uint256 amountOut) {
        address A = address(11);
        address B = address(22);
        address C = address(33);
        address D = address(44);

        if (params.tokenIn == A && params.tokenOut == D) {
            return params.amountIn * 2;
        }

        if (params.tokenIn == A && params.tokenOut == B) {
            return params.amountIn * 2;
        }

        if (params.tokenIn == B && params.tokenOut == D) {
            return params.amountIn * 2;
        }

        if (params.tokenIn == A && params.tokenOut == C) {
            return params.amountIn * 3;
        }

        if (params.tokenIn == C && params.tokenOut == D) {
            return params.amountIn * 2;
        }

        if (params.tokenIn == B && params.tokenOut == C) {
            return params.amountIn * 3;
        }

        return 0;
    }
}

contract DexAggregatorV2ThreeHopRouteTest is Test {
    MockV2RouterFour v2;
    MockV3RouterFour v3Router;
    MockSmartQuoterFour v3Quoter;

    DexAggregatorV2 agg;

    address constant TOKEN_A = address(11);
    address constant TOKEN_B = address(22);
    address constant TOKEN_C = address(33);
    address constant TOKEN_D = address(44);

    function setUp() public {
        v2 = new MockV2RouterFour();
        v3Router = new MockV3RouterFour();
        v3Quoter = new MockSmartQuoterFour();

        address[] memory routing = new address[](2);
        routing[0] = TOKEN_B;
        routing[1] = TOKEN_C;

        agg = new DexAggregatorV2(
            address(v2),
            address(v3Router),
            address(v3Quoter),
            address(this),
            routing
        );
    }

    function testBestSequenceQuoteSelectsThreeHopRoute() public {
        DexAggregatorV2.Route memory route = agg.getBestSequenceQuote(
            TOKEN_A,
            TOKEN_D,
            1 ether
        );

        // Direct A -> D = 2 ether
        // A -> B -> D = 4 ether
        // A -> C -> D = 6 ether
        // A -> B -> C -> D = 12 ether (best)

        assertEq(route.amountOut, 12 ether);
        assertEq(route.hops.length, 3);

        assertEq(route.hops[0].tokenIn, TOKEN_A);
        assertEq(route.hops[0].tokenOut, TOKEN_B);

        assertEq(route.hops[1].tokenIn, TOKEN_B);
        assertEq(route.hops[1].tokenOut, TOKEN_C);

        assertEq(route.hops[2].tokenIn, TOKEN_C);
        assertEq(route.hops[2].tokenOut, TOKEN_D);
    }
}
