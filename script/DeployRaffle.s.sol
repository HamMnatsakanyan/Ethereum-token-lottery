// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { Raffle } from "../src/Raffle.sol";
import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { CreateSubscription, FundSubscription, AddConsumer } from "./Interactions.s.sol";

contract DeployRaffle is Script {

    function run() external returns(Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            uint256 ticketPrice, 
            uint256 interval, 
            address vrfCoordinator, 
            bytes32 keyHash,
            uint64  subscriptionId,
            uint32  callbackGasLimit,
            address linkAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        console.log(deployerKey);

        if(subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployerKey);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, linkAddress, deployerKey);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            ticketPrice, 
            interval, 
            vrfCoordinator, 
            keyHash,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subscriptionId, deployerKey);

        return (raffle, helperConfig);
    }

}