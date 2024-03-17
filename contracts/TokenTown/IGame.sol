// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Property} from "./Property.sol";

interface IGame {
    //Below are the events
    event GameStarted(address indexed starter, uint256 gameStarted);
    event CrossedGo(address indexed player);
    event RolledDice(address indexed player, uint256 dice1, uint256 dice2);
    event VisitJail(address indexed player);
    event SentToJail(address indexed player);
    event PlayerWon(address indexed player, uint256 amount);
    event ReceivingAirdrop(address indexed player, uint256 amount);
    event RentPaid(address indexed player, uint256 amount);
    event UserLose(address indexed player);

    type player is address;

    //Below are the structs
    struct GameState {
        address currentPlayer; //This is the player that is rolling
        address[] players; //Array of the players in the game
        uint256 numberOfPlayers; //The total number of players
        address chosenCurrency; //The chosen currency (e.g HypApeCoin or USDC)
        mapping(address => uint256) playerPosition; //Goes from player address to position on board
        mapping(address => address) playerOwnedProperty;
        Property[] propertyList; //List of all properties
        uint256 buyIn;
    }
}
