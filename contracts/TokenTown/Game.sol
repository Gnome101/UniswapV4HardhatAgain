// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "hardhat/console.sol";
import {IGame} from "./IGame.sol";
import {Property} from "./Property.sol";

contract Game is IGame {
    address public poolManager;
    uint256 gameID;

    mapping(address => uint256) public playerToGame;
    mapping(uint256 => GameState) public idToGameState;
    string[] usualNamesAndSymbols;

    constructor(address _poolManager) {
        require(
            _poolManager != address(0),
            "Pool manager address cannot be zero."
        );
        poolManager = _poolManager;

        // You can use console.log for debugging purposes
        console.log("Game contract deployed by:", msg.sender);
        console.log("Pool Manager set to:", poolManager);
    }

    // Implementing the start function from IGame
    function setUp() external {
        idToGameState[gameID].players.push(msg.sender);
        idToGameState[gameID].numberOfPlayers++;
        //Mint 8 ERC20s with a balance of 4 for each
        for (uint256 i = 0; i < usualNamesAndSymbols.length; i++) {
            Property property = new Property(
                usualNamesAndSymbols[i],
                usualNamesAndSymbols[i + 1],
                4
            );
            console.log(usualNamesAndSymbols[i], usualNamesAndSymbols[i + 1]);
            idToGameState[gameID].propertyList.push(property);
            i++;
        }

        //Add all of the ERC20s to the game state
        //Open up a game for other users to join
        gameID++;
    }

    function joinGame(uint256 _gameID) external {
        idToGameState[_gameID].players.push(msg.sender);
        idToGameState[_gameID].numberOfPlayers++;
    }

    function createProperty() internal {
        //
    }

    function addNames(string[] memory list) public {
        require(list.length % 2 == 0, "Must be even");
        require(list.length > 0, "Must have stuff ");
        usualNamesAndSymbols = list;
    }
}

//Idea for how game is going to work
//There are 8 different property groups
// There are railways
//Community Chests & Chance Cards
//Free Parking
//Jail
//Go

//The struct will contain all of the players
//Lets say there are four players

//We use ChainLink for getting Dice
