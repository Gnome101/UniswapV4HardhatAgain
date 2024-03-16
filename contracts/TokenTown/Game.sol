// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "hardhat/console.sol";
import {IGame} from "./IGame.sol";
import {Property} from "./Property.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Game is IGame /*, VRFConsumerBaseV2*/ {
    //Below is for chainlink
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    address public poolManager;

    //Below is for the game
    uint256 gameID;
    mapping(address => uint256) public playerToGame;
    mapping(uint256 => GameState) public idToGameState;
    mapping(address => bool) public userRoll; //User can roll
    mapping(address => uint256) public userRollsRow; //# of rolls in a row

    string[] usualNamesAndSymbols;
    uint256 constant MAX_STEPS = 40;
    mapping(address => uint256) addressToGame;

    constructor(
        address _poolManager // address vrfCoordinator
    ) /*VRFConsumerBaseV2(vrfCoordinator)*/ {
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
    function setUp(address selectedToken, uint256 bankStart) external {
        SafeERC20.safeTransferFrom(
            IERC20(selectedToken),
            msg.sender,
            address(this),
            bankStart
        );
        idToGameState[gameID].players.push(msg.sender);
        addressToGame[msg.sender] = gameID;
        idToGameState[gameID].numberOfPlayers++;
        //Mint 8 ERC20s with a balance of 4 for each
        _createAndAssignProperties(gameID);
        //Open up a game for other users to join
        idToGameState[gameID].chosenCurrency = selectedToken;

        gameID++;
    }

    function _createAndAssignProperties(uint256 _gameID) internal {
        for (uint256 i = 0; i < usualNamesAndSymbols.length; i++) {
            Property property = new Property(
                usualNamesAndSymbols[i],
                usualNamesAndSymbols[i + 1],
                4
            );
            // console.log(usualNamesAndSymbols[i], usualNamesAndSymbols[i + 1]);
            //Add all of the ERC20s to the game state
            idToGameState[_gameID].propertyList.push(property);
            i++;
        }
    }

    function joinGame() external {
        if (gameID == 0) {
            revert("No games exist");
        }
        uint256 curentGame = gameID - 1;
        idToGameState[curentGame].players.push(msg.sender);
        addressToGame[msg.sender] = gameID;
        idToGameState[curentGame].numberOfPlayers++;
    }

    function startGame() external {
        //This will begin the game for all players, and begin a move for the first player.
        if (gameID == 0) {
            revert("A game has not been setUp() yet");
        }
        uint256 curentGameID = gameID - 1;
        userRoll[msg.sender] = true;
        idToGameState[curentGameID].currentPlayer = msg.sender;
    }

    function beginMove() external {
        require(gameID > 0, "No Game Created");
        uint256 currentGameID = addressToGame[msg.sender];

        require(
            idToGameState[currentGameID].currentPlayer == msg.sender,
            "Must be current Player"
        );

        require(userRoll[msg.sender], "User cannot roll");
        userRoll[msg.sender] = false;
        (bool rollAgain, uint256 stepsFoward) = rollDice(); //We would stop here and wait for chainlink to respnd if using it
        if (userInJail[msg.sender]) {
            if (rollAgain) {
                //User leaves jail
                userInJail[msg.sender] = false;
            }
            return; //No matter what, just sit there
        }

        if (rollAgain) {
            userRoll[msg.sender] = true;
            userRollsRow[msg.sender]++;
            if (userRollsRow[msg.sender] > 3) {
                sendUserToJail(msg.sender);
            }
        }
        _updatePlayerPosition(currentGameID, msg.sender, stepsFoward);
    }

    function rollDice() public view returns (bool snake, uint256 total) {
        //Upon implementation add chainlink here
        uint256 dice1 = (uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender))
        ) % 6) + 1;

        uint256 dice2 = (uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender, dice1))
        ) % 6) + 1;
        total = dice1 + dice2;
        if (dice1 == dice1) {
            snake = true;
        }
    }

    // function fulfillRandomness(
    //     bytes32 requestId,
    //     uint256 randomness
    // ) internal override {
    //     randomResult = randomness;
    //     // Add additional logic to handle randomness
    // _updatePlayerPosition(currentGameID, msg.sender, stepsFoward);
    // }

    function createProperty() internal {
        //
    }

    function _updatePlayerPosition(
        uint256 _gameID,
        address player,
        uint256 stepsFoward
    ) internal {
        idToGameState[_gameID].playerPosition[player] += stepsFoward;
        if (stepsFoward >= MAX_STEPS) {
            emit CrossedGo(player);
            //Need to give the player moneys here!
            //User arrived at the start
            idToGameState[_gameID].playerPosition[player] -= MAX_STEPS;
        }
    }

    function addNames(string[] memory list) public {
        require(list.length % 2 == 0, "Must be even");
        require(list.length > 0, "Must have stuff ");
        usualNamesAndSymbols = list;
    }

    function purchaseProperty() public returns (uint256) {}

    function sellProperty() public returns (uint256) {}

    mapping(address => uint256) public daysInJail;
    mapping(address => bool) public userInJail;

    function sendUserToJail(address user) public {
        userInJail[user] = true;
    }

    function getMyPosition() public view returns (uint256) {}

    function getMyProperties() public view returns (uint256) {}

    function getAllProperties() public view returns (string[] memory list) {
        return usualNamesAndSymbols;
    }

    function getPropertyValue() public view returns (uint256) {}

    //These are all of the helper fucntions for a game
    function getActiveNumberOfPlayers() public view returns (uint256) {
        if (gameID == 0) {
            return 0;
        }
        uint256 currentGameID = gameID - 1;
        return idToGameState[currentGameID].numberOfPlayers;
    }

    function getActiveGameID() public view returns (uint256) {
        if (gameID == 0) {
            return 0;
        }
        uint256 currentGameID = gameID - 1;
        return currentGameID;
    }

    function getActivePlayers() public view returns (address[] memory) {
        if (gameID == 0) {
            address[] memory list;
            return list;
        }
        uint256 currentGameID = gameID - 1;
        return idToGameState[currentGameID].players;
    }

    function getCurrentChosenCurrency() public view returns (address) {
        if (gameID == 0) {
            return address(0);
        }
        uint256 currentGameID = gameID - 1;
        return idToGameState[currentGameID].chosenCurrency;
    }

    function getCurrentPlayer() public view returns (address) {
        if (gameID == 0) {
            return address(0);
        }
        uint256 currentGameID = gameID - 1;
        return idToGameState[currentGameID].currentPlayer;
    }

    function getPlayerPosition(address user) public view returns (uint256) {
        if (gameID == 0) {
            return 0;
        }
        uint256 currentGameID = gameID - 1;
        return idToGameState[currentGameID].playerPosition[user];
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
