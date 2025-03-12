// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {console} from "forge-std/Script.sol";

// Creating a sample raffle
contract Raffle is VRFConsumerBaseV2 {

    error Raffle__NotEnoughEth();
    error Raffle__TransferFailed();
    error Raffle__RaffleClosed();
    error Raffle__UpkeepNotNeeded();

    // Type Declarations
    enum RaffleState {
        OPEN, // 0
        CALCULATING,
        CLOSED
    }

    // State Variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 3;

    uint256 private immutable i_ticketPrice;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint64  private immutable i_subscriptionId;
    uint32  private immutable i_callbackGasLimit;

    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;


    // Events
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 ticketPrice, 
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 keyHash,
        uint64  subscriptionId,
        uint32  callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_ticketPrice      = ticketPrice;
        i_interval         = interval;
        i_keyHash          = keyHash;
        i_vrfCoordinator   = VRFCoordinatorV2Interface(vrfCoordinator);
        s_lastTimeStamp    = block.timestamp;
        i_subscriptionId   = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {

        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleClosed();
        }

        if(msg.value < i_ticketPrice){
            revert Raffle__NotEnoughEth();
        }
        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */) public view returns(bool upkeepNeeded, bytes memory /* performkData */){

        bool timePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timePassed && isOpen && hasPlayers);

        return(upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes memory /* performkData */) external {

        (bool upkeepNeeded, ) = checkUpkeep("");
        if(!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded();
        }
        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {

        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recentWinner = winner;

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);
        s_raffleState = RaffleState.OPEN;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
        }

    }

    // Getter Functions
    function getTicketPrive() public view returns(uint256) {
        return i_ticketPrice;
    }

    function getRaffleState() public view returns(RaffleState) {
        return s_raffleState;
    }

    function getPlayersArray() public view returns(address payable[] memory) {
        return s_players;
    }

    function getPlayerAddress(uint256 index) public view returns(address payable) {
        return s_players[index];
    }

    function getRecentWinner() public view returns(address) {
        return s_recentWinner;
    }
}