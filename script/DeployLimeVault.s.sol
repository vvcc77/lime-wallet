// SPDX-License-Identifier: MIT ft @vvcc77 & @PhoenixZeroph Auditor
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {LimeVault, IUsdPriceOracle} from "../src/LimeVault.sol";

contract DeployLimeVault is Script {
    // ENV esperadas:
    // OWNER_ADDRESS, TREASURY
    // (luego podrás registrar tokens con allowToken() en una tx separada)
    function run() external {
        address owner = vm.envAddress("OWNER_ADDRESS");
        address treasury = vm.envOr("TREASURY", address(0));

        vm.startBroadcast();
        LimeVault vault = new LimeVault(owner, treasury);
        vm.stopBroadcast();

        console2.log("LimeVault:", address(vault));
    }
}
