// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/DexAggregator.sol";

contract SepoliaLiveQuoteTest is Test {
    // -------------------------------------------------
    // Sepolia addresses
    // -------------------------------------------------

    // Uniswap V3 SwapRouter02 on Sepolia
    address constant V3_ROUTER =
    0x3BFa4769fB09EEFC5A80d6E87ff9b8603B9A72E1;

    // Uniswap V3 QuoterV2 on Sepolia
    address constant V3_QUOTER = 0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3;

    // There is no canonical Uniswap V2 on Sepolia anymore,
    // so use Sushi / Pancake / local fork if needed.
    // Example placeholder:
    address constant V2_ROUTER = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;//address(0);//0x0000000000000000000000000000000000000000;

    // -------------------------------------------------
    // Example Sepolia token addresses
    // Replace with tokens you actually deployed / want
    // -------------------------------------------------

    address constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

    // Example: Sepolia USDC (Circle test deployment may differ)
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    // Example LINK token on Sepolia
    address constant LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    DexAggregator agg;

    function setUp() public {
        agg = new DexAggregator(
            V2_ROUTER,
            V3_ROUTER,
            V3_QUOTER,
            address(this)
        );
    }

    function testLiveQuoteWethToUsdc() public {
        uint256 amountIn = 0.01 ether;

        (uint256 amountOut, uint24 fee) = agg.quoteV3Best(
            WETH,
            USDC,
            amountIn
        );

        console.log("WETH -> USDC amountOut =", amountOut);
        console.log("Selected fee tier =", fee);

        assertGt(amountOut, 0);
    }

    function testLiveQuoteWethToLink() public {
        uint256 amountIn = 0.01 ether;

        (uint256 amountOut, uint24 fee) = agg.quoteV3Best(
            WETH,
            LINK,
            amountIn
        );

        console.log("WETH -> LINK amountOut =", amountOut);
        console.log("Selected fee tier =", fee);

        assertGt(amountOut, 0);
    }

    function testLiveBestQuote() public {
        DexAggregator.Quote memory q = agg.getBestQuote(
            WETH,
            USDC,
            0.01 ether
        );

        console.log("Best amountOut =", q.amountOut);
        console.log("useV3 =", q.useV3);
        console.log("fee =", q.fee);

        assertGt(q.amountOut, 0);
    }
}