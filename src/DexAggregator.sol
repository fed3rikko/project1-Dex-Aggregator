// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

import "forge-std/console.sol";

contract DexAggregator is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IUniswapV2Router02 public immutable v2Router;
    ISwapRouter public immutable v3Router;
    IQuoterV2 public immutable v3Quoter;

    uint24[3] public v3Fees = [500, 3000, 10000];

    struct Quote {
        uint256 amountOut;
        bool useV3;
        uint24 fee;
    }

    constructor(
        address _v2Router,
        address _v3Router,
        address _v3Quoter,
        address owner
    ) Ownable(owner) {
        v2Router = IUniswapV2Router02(_v2Router);
        v3Router = ISwapRouter(_v3Router);
        v3Quoter = IQuoterV2(_v3Quoter);
    }

    function quoteV2(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256 amountOut) {
        address[] memory path;
        path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = v2Router.getAmountsOut(amountIn, path);
        return amounts[1];
    }

    function quoteV3Best(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (uint256 bestAmountOut, uint24 bestFee) {
        console.log("SEARCHING IS RUNNING =");
        for (uint256 i = 0; i < v3Fees.length; i++) {
            uint24 fee = v3Fees[i];

            try v3Quoter.quoteExactInputSingle(
                IQuoterV2.QuoteExactInputSingleParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    amountIn: amountIn,
                    fee: fee,
                    sqrtPriceLimitX96: 0
                })
            ) returns (
                uint256 amountOut,
                uint160,
                uint32,
                uint256
            ) {
                if (amountOut > bestAmountOut) {
                    bestAmountOut = amountOut;
                    bestFee = fee;
                    console.log("best current amountOut =", amountOut);
                }
            } catch {}
        }
    }

    function getBestQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public returns (Quote memory q) {
        uint256 v2Amount = quoteV2(tokenIn, tokenOut, amountIn);
        (uint256 v3Amount, uint24 v3Fee) = quoteV3Best(
            tokenIn,
            tokenOut,
            amountIn
        );

        if (v3Amount > v2Amount) {
            return Quote(v3Amount, true, v3Fee);
        }

        return Quote(v2Amount, false, 0);
    }

    function swapV2(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(address(v2Router), amountIn);

        address[] memory path;
        path = new address[](2);

        path[0] = tokenIn;
        path[1] = tokenOut;

        uint256[] memory amounts = v2Router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            msg.sender,
            deadline
        );

        amountOut = amounts[1];
    }

    function swapV3(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        uint24 fee
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).approve(address(v3Router), amountIn);

        amountOut = v3Router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: msg.sender,
                deadline: deadline,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        Quote memory best = getBestQuote(
            tokenIn,
            tokenOut,
            amountIn
        );

        require(best.amountOut >= minAmountOut, "Slippage");

        IERC20(tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            amountIn
        );

        if (best.useV3) {
            amountOut = swapV3(
                tokenIn,
                tokenOut,
                amountIn,
                minAmountOut,
                deadline,
                best.fee
            );
        } else {
            amountOut = swapV2(
                tokenIn,
                tokenOut,
                amountIn,
                minAmountOut,
                deadline
            );
        }
    }
}