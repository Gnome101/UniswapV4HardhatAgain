// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Property} from "./Property.sol";

interface IGame {
    //Below are the events
    event GameStarted(address indexed starter);
    event GameEnded(address indexed ender);
    event GamePlayed(address indexed player);
    type player is address;

    //Below are the structs
    struct GameState {
        address[] players; //Array of the players in the game
        uint256 numberOfPlayers; //The total number of players
        address chosenCurrency; //The chosen currency (e.g HypApeCoin or USDC)
        mapping(address => uint256) playerPosition; //Goes from player address to position on board
        mapping(address => address) playerOwnedProperty;
        Property[] propertyList; //List of all properties
    }
}
