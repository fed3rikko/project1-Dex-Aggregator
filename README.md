# Dex Aggregator with DFS-Based Routing Optimization

## 1. Overview

This project implements a decentralized exchange (DEX) aggregator smart contract that computes optimal swap routes across multiple liquidity sources such as Uniswap V2 and Uniswap V3-style pools.

The goal is to maximize output tokens by exploring multi-hop swap paths instead of relying only on direct trades or fixed routing strategies.

Unlike traditional multi-hop (where we do 2 swaps), we do multistep Depth Search (DFS) algorithm to explore all possible token paths up to a configurable maximum depth.
Each edge in the graph represents a swap between two tokens, and each edge has a dynamic weight determined by on-chain price quotes. The contract selects the route that produces the highest final output amount.

---

## 2. Core Idea

The decentralized exchange environment is modeled as a directed weighted graph:

- **Nodes** represent tokens
- **Edges** represent swap pairs between tokens
- **Weights** represent output amounts received from executing a swap


The V2 evaluates all valid paths from a given input token to a target output token and selects the path that maximizes the resulting output amount.

---

in V3 i realized more complicated algorithm where i split given amout of tokens and search for each part optimal non-intersecting pathes. 

I do it gready: first i search optimal path for part of amout after i search for seccond path which does not intersect first. Since this it is proxy not genral algo.

---

## 3. Architecture

The system is implemented in a single aggregator contract with three core components:

### 3.1 Quote Engine

The quote engine is responsible for computing the best available price between two tokens. It compares multiple liquidity sources:

- Uniswap V2-style pools using `getAmountsOut`
- Uniswap V3-style pools using `quoteExactInputSingle` across multiple fee tiers

The best available quote is selected dynamically.

### Key function:

```solidity
getBestQuote(tokenIn, tokenOut, amountIn)
```

This function returns a Quote struct containing:
	•	amountOut: the best output amount
	•	useV3: whether V3 routing is optimal
	•	fee: selected V3 fee tier (if applicable)

### 3.2 Routing Engine (DFS)

The routing engine is the core optimization component of the system. It computes the best swap path using a Depth-First Search (DFS) algorithm over a token graph.

The graph is defined as:

```text
Nodes  = tokens
Edges  = possible swaps between tokens
Weight = dynamic output amount from quote function
```
```solidity
getBestSequenceQuote(tokenIn, tokenOut, amountIn)
```

DFS algo
The algorithm performs recursive exploration of the token graph:
	•	Visits each reachable token starting from tokenIn
	•	Avoids cycles using a visited[] array
	•	Builds routes incrementally using currentRoute
	•	Evaluates each complete or partial path using getBestQuote
	•	Updates global best result when a better route is found
