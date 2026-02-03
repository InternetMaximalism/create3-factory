// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";

import {CREATE3Factory} from "../src/CREATE3Factory.sol";

contract DeployScript is Script {
    function run() public returns (CREATE3Factory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = keccak256("intmax");
        factory = new CREATE3Factory{salt: salt}();

        vm.stopBroadcast();
    }
}
