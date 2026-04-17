// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import "../src/DexAggregatorV2.sol";

contract DeployDexAggregatorV2 is Script {

    address constant V3_ROUTER =
        0x3BFa4769fB09EEFC5A80d6E87ff9b8603B9A72E1;

    address constant V3_QUOTER =
        0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3;

    address constant V2_ROUTER =
        0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;

    address constant WETH =
        0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;

    address constant USDC =
        0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    address constant LINK =
        0x779877A7B0D9E8603169DdbD7836e478b4624789;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);

        address[] memory tokens = new address[](3);
        tokens[0] = WETH;
        tokens[1] = USDC;
        tokens[2] = LINK;

        DexAggregatorV2 agg = new DexAggregatorV2(
            V2_ROUTER,
            V3_ROUTER,
            V3_QUOTER,
            msg.sender,
            tokens
        );

        vm.stopBroadcast();

        console.log("DexAggregatorV2 deployed at:", address(agg));
    }
}