// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { VRFCoordinatorV2Mock } from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";
import { DevOpsTools } from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {

    function getConfig() public returns(uint64){
 
        HelperConfig helperConfig = new HelperConfig();
        (, ,address vrfAddress , , , , , uint256 deployerKey) = helperConfig.activeNetworkConfig();

        return createSubscription(vrfAddress, deployerKey);
    }

    function createSubscription(address vrfAddress, uint256 deployerKey) public returns(uint64){ 

            vm.startBroadcast(deployerKey);
            uint64 subId = VRFCoordinatorV2Mock(vrfAddress).createSubscription();
            vm.stopBroadcast();

        return subId;
    }

    function run() external returns(uint64) {
        return getConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function getNetworkConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (, ,address vrfAddress , ,uint64 subId , ,address link, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfAddress, subId, link, deployerKey);
    }

    function fundSubscription(address vrfAddress, uint64 subId ,address link, uint256 deployerKey) public {
            console.log("subId ", subId);

        if(block.chainid == 31337){
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfAddress).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfAddress,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        getNetworkConfig();
    }
}

contract AddConsumer is Script {

    function getConfig(address raffleAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        (, ,address vrfAddress , ,uint64 subId , , , uint256 deployerKey) = helperConfig.activeNetworkConfig();
            
        addConsumer(raffleAddress, vrfAddress, subId, deployerKey);
    }

    function addConsumer(address raffleAddress, address vrfAddress, uint64 subId, uint256 deployerKey) public {

        console.log(deployerKey);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfAddress).addConsumer(subId, raffleAddress);
        vm.stopBroadcast();
    }

    function run() external {
        address raffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);

        getConfig(raffleAddress);
    }
}