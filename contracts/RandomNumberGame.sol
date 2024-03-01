// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract RandomWinnerGame is VRFConsumerBaseV2, ConfirmedOwner {
    // Chainlink variables
    bytes32 public keyHash;
    uint256 public fee;

    // Game variables
    address[] public players;
    uint8 public maxPlayers;
    bool public gameStarted;
    uint256 public entryFee;
    uint256 public gameId;

    // Events
    event GameStarted(uint256 gameId, uint8 maxPlayers, uint256 entryFee);
    event PlayerJoined(uint256 gameId, address player);
    event GameEnded(uint256 gameId, address winner, bytes32 requestId);

    // constructor(address vrfCoordinator, address linkToken)
    //     VRFConsumerBase(vrfCoordinator, linkToken) {
    //     // Constructor logic
    // }

    constructor(
        uint64 subscriptionId
    )
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625);
        s_subscriptionId = subscriptionId;
    }

    function setConfig(bytes32 _keyHash, uint256 _fee) external onlyOwner {
        keyHash = _keyHash;
        fee = _fee;
    }

    function startGame(uint8 _maxPlayers, uint256 _entryFee) public onlyOwner {
        require(!gameStarted, "Game is currently running");
        delete players;
        maxPlayers = _maxPlayers;
        gameStarted = true;
        entryFee = _entryFee;
        gameId += 1;
        emit GameStarted(gameId, maxPlayers, entryFee);
    }

    function joinGame() public payable {
        require(gameStarted, "Game has not been started yet");
        require(msg.value == entryFee, "Value sent is not equal to entryFee");
        require(players.length < maxPlayers, "Game is full");
        players.push(msg.sender);
        emit PlayerJoined(gameId, msg.sender);
        if(players.length == maxPlayers) {
            getRandomWinner();
        }
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal virtual override {
        uint256 winnerIndex = randomness % players.length;
        address winner = players[winnerIndex];
        (bool sent,) = winner.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
        emit GameEnded(gameId, winner, requestId);
        gameStarted = false;
    }

    function getRandomWinner() private returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    // Receive and fallback functions
    receive() external payable {}
    fallback() external payable {}
}
