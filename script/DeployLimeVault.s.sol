// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LimeVault} from "../src/LimeVault.sol";

contract DeployLimeVault is Script {
    function run() external {
        address token = vm.envAddress("TOKEN_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address treasury = vm.envOr("TREASURY", address(0));

        vm.startBroadcast();
        LimeVault vault = new LimeVault(IERC20(token), owner, treasury);
        vm.stopBroadcast();

        console2.log("LimeVault:", address(vault));
    }
}
