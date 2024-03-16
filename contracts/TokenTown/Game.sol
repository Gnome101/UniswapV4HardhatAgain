// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "hardhat/console.sol";
import {IGame} from "./IGame.sol";

contract Game is IGame {
    address public poolManager;
    uint256 gameID;

    mapping(address => uint256) public playerToGame;
    mapping(uint256 => GameState) public idToGameState;

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
        //Mint 8 ERC20s with a balance of 4 for each
        //Add all of the ERC20s to the game state
        //Open up a game for other users to join
    }

    function joinGame(uint256 _gameID) external {}

    function createProperty() internal {
        //
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
