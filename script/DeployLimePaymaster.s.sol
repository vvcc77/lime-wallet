// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IEntryPoint} from "@openzeppelin/contracts/account-abstraction/interfaces/IEntryPoint.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LimePaymaster, IPriceOracle} from "../src/LimePaymaster.sol";

contract DeployLimePaymaster is Script {
    function run() external {
        address entryPoint = vm.envAddress("ENTRYPOINT");
        address usdc       = vm.envAddress("TOKEN_ADDRESS");
        address oracle     = vm.envAddress("ORACLE_ADDRESS");

        vm.startBroadcast();
        LimePaymaster pm = new LimePaymaster(
            IEntryPoint(entryPoint),
            IERC20(usdc),
            IPriceOracle(oracle)
        );
        vm.stopBroadcast();

        console2.log("LimePaymaster:", address(pm));
    }
}
