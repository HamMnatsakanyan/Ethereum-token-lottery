// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Raffle } from "../../src/Raffle.sol";
import { Test, console } from "forge-std/Test.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { Vm } from "forge-std/Vm.sol";
import { VRFCoordinatorV2Mock } from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 ticketPrice;
    uint256 interval; 
    address vrfCoordinator; 
    bytes32 keyHash;
    uint64  subscriptionId;
    uint32  callbackGasLimit;
    address linkAddress;
    uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    address payable[] players;

    event EnteredRaffle(address indexed player);

    function setUp() external {

        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            ticketPrice, 
            interval, 
            vrfCoordinator, 
            keyHash,
            subscriptionId,
            callbackGasLimit,
            linkAddress,
            deployerKey
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleinitializesInOpenTest() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleInsufficientBalance() public {

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayers() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: ticketPrice}();
        players = raffle.getPlayersArray();

        assert(players[0] == address(PLAYER));
    }

    function testEmitsEventOnEnterance() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();

    }

    function testCheckUpkeepHasNoPlayers() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testPerformUpkeepCheckUpkeepTrue() public playerEnterdAndTimePassed{
        raffle.performUpkeep("");
    }

    function testPerformUpkeepCheckUpkeepFalse() public {
        vm.expectRevert(Raffle.Raffle__UpkeepNotNeeded.selector);
        raffle.performUpkeep("");
    }

    function testRaffleStateCalculating() public playerEnterdAndTimePassed{

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleClosed.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();
    }

    function testCheckUpkeepRaffleClosed() public playerEnterdAndTimePassed {

        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testPerformUpkeepEmitsEvent() public playerEnterdAndTimePassed {

        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        assert(uint256(requestId) > 0);
    }

    function testFulfillRandomWordsReverts(uint256 randomRequestId) public skipIfFork {

        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

    }

    function testFulfillRandomWordsSendsMoneyandResets() public skipIfFork playerEnterdAndTimePassed {

        for(uint256 i = 1; i < 5; i++){
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: ticketPrice}();
        }

        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        assert(raffle.getPlayersArray().length == 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE  + (4 * ticketPrice));

    }

    modifier playerEnterdAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ticketPrice}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipIfFork() {
        if(block.chainid == 11155111) {
            return;
        }
        _;
    }

}
