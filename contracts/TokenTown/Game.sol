// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "hardhat/console.sol";
import {IGame} from "./IGame.sol";
import {Property} from "./Property.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPoolManager} from "../Uniswap/V4-Core/interfaces/IPoolManager.sol";

import {Currency, CurrencyLibrary} from "../Uniswap/V4-Core/types/Currency.sol";
import {PoolKey} from "../Uniswap/V4-Core/types/PoolKey.sol";
import {MyHook} from "../MyHook.sol";
import {IHooks} from "../Uniswap/V4-Core/interfaces/IHooks.sol";
import {TickMath} from "../Uniswap/V4-Core/libraries/TickMath.sol";

contract Game is IGame /*, VRFConsumerBaseV2*/ {
    //Below is for chainlink
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    address public immutable poolManager;
    MyHook public immutable mainHook;

    //Below is for the game
    uint256 gameID;
    mapping(address => uint256) public playerToGame;
    mapping(uint256 => GameState) public idToGameState;
    mapping(address => bool) public userRoll; //User can roll
    mapping(address => uint256) public userRollsRow; //# of rolls in a row

    mapping(uint256 => bool) rentExists;
    mapping(uint256 => address[]) usersThatOwn;

    string[] usualNamesAndSymbols;
    uint256 constant MAX_STEPS = 20;
    mapping(address => uint256) addressToGame;

    mapping(address => TokenInfo) getCurrencyInfo;

    struct TokenInfo {
        uint8[4] priceStarts;
        uint8[4] priceChanges;
        uint256 userStart;
    }
    mapping(address => PoolKey) addressToKey;

    constructor(
        address _poolManager,
        address _mainHook // address vrfCoordinator
    ) /*VRFConsumerBaseV2(vrfCoordinator)*/ {
        require(
            _poolManager != address(0),
            "Pool manager address cannot be zero."
        );
        poolManager = _poolManager;
        mainHook = MyHook(_mainHook);
        // You can use console.log for debugging purposes
        // console.log("Game contract deployed by:", msg.sender);
        // console.log("Pool Manager set to:", poolManager);
    }

    //Function for testing
    function reclaimTokens(address token) external {
        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
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
        // console.log("GS", idToGameState[gameID].numberOfPlayers);
        idToGameState[gameID].chosenCurrency = selectedToken;

        //Mint 8 ERC20s with a balance of 4 for each
        _createAndAssignProperties(gameID);
        _prepareProperties(idToGameState[gameID].propertyList, selectedToken);

        //Open up a game for other users to join
        //Add liquidity with the pools

        gameID++;
    }

    function _prepareProperties(
        Property[] memory propertyList,
        address selectedToken
    ) internal {
        for (uint256 i = 0; i < propertyList.length; i++) {
            Property property = propertyList[i];
            _preparePoolProperty(property, selectedToken);
        }
    }

    function _preparePoolProperty(Property property, address token) internal {
        //First we need to initalize the pool
        address token0 = address(property);
        address token1 = token;
        if (token1 < token0) {
            address temp = token0;
            token0 = token1;
            token1 = temp;
        }
        Currency currency_property = Currency.wrap(token0);
        Currency currency_token = Currency.wrap(token1);

        uint24 _fee = 0;
        int24 tickSpacing = 60;
        address hookAddy = address(mainHook);
        IHooks hooks = IHooks(hookAddy);

        PoolKey memory key = PoolKey(
            currency_property,
            currency_token,
            _fee,
            tickSpacing,
            hooks
        );
        addressToKey[address(property)] = key;
        uint160 sqrtPrice = TickMath.getSqrtRatioAtTick(0);

        mainHook.startPool(key, sqrtPrice, "0x", block.timestamp + 10);
        // console.log("Pool started");
        // uint256 totalTokenNumber = 4 *
        property.getPriceStart() + 6 * property.getPriceIncrease();
        //Then we need to add liquidity
        // SafeERC20.safeTransferFrom(
        //     IERC20(token),
        //     msg.sender,
        //     address(this),
        //     totalTokenNumber
        // );

        SafeERC20.safeTransfer(
            IERC20(address(property)),
            address(mainHook),
            IERC20(address(property)).balanceOf(address(this))
        );
        // mainHook.addProperty(property);
    }

    function _createAndAssignProperties(uint256 _gameID) internal {
        uint8[4] memory usualList = [1, 6, 11, 16]; // These are the positions that all of the properties start on
        uint8[4] memory priceStarts;
        uint8[4] memory priceChanges;
        uint8[4] memory rentStarts;

        TokenInfo memory tInfo = getCurrencyInfo[
            idToGameState[gameID].chosenCurrency
        ];

        if (tInfo.userStart > 0) {
            priceStarts = tInfo.priceStarts;
            priceChanges = tInfo.priceChanges;
        } else {
            priceStarts = [60, 120, 160, 250];
            rentStarts = [10, 30, 50, 70];
            priceChanges = [5, 10, 20, 50];
        }

        for (uint256 i = 0; i < usualNamesAndSymbols.length; i++) {
            Property property = new Property(
                usualNamesAndSymbols[i],
                usualNamesAndSymbols[i + 1],
                4,
                usualList[i / 2],
                priceStarts[i / 2],
                rentStarts[i / 2],
                priceChanges[i / 2]
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
        address[] memory list = idToGameState[curentGame].players;
        for (uint i = 0; i < list.length; i++) {
            if (msg.sender == list[i]) {
                revert("Can not join twice");
            }
        }
        idToGameState[curentGame].players.push(msg.sender);
        addressToGame[msg.sender] = curentGame;
        uint256 buyIn = idToGameState[curentGame].buyIn /
            idToGameState[curentGame].players.length;
        SafeERC20.safeTransferFrom(
            IERC20(idToGameState[curentGame].chosenCurrency),
            msg.sender,
            address(this),
            buyIn
        );
        idToGameState[curentGame].buyIn += buyIn;

        idToGameState[curentGame].numberOfPlayers++;
    }

    function getBuyIn() public view returns (uint256) {
        if (gameID == 0) {
            revert("No games exist");
        }
        uint256 curentGame = gameID - 1;
        uint256 buyIn = idToGameState[curentGame].buyIn /
            idToGameState[curentGame].players.length;
        return buyIn;
    }

    function startGame() external {
        //This just starts the most recently made game
        //This will begin the game for all players, and begin a move for the first player.
        if (gameID == 0) {
            revert("A game has not been setUp() yet");
        }
        uint256 curentGameID = gameID - 1;
        userRoll[msg.sender] = true;
        idToGameState[curentGameID].currentPlayer = msg.sender;
        emit GameStarted(msg.sender, gameID);
        //Now we have to distribute moneys
        uint256 amount = getCurrencyInfo[
            idToGameState[curentGameID].chosenCurrency
        ].userStart;
        if (amount == 0) {
            amount = 70 * 10 ** 18;
        }
        for (uint i = 0; i < idToGameState[curentGameID].players.length; i++) {
            SafeERC20.safeTransfer(
                IERC20(idToGameState[curentGameID].chosenCurrency),
                idToGameState[curentGameID].players[i],
                amount
            );
        }
    }

    function _rollDice(
        address user
    ) public returns (bool snake, uint256 total) {
        //Upon implementation add chainlink here
        uint256 dice1 = (uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)
            )
        ) % 6) + 1;

        uint256 dice2 = (uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    msg.sender,
                    dice1
                )
            )
        ) % 6) + 1;
        total = dice1 + dice2;
        emit RolledDice(user, dice1, dice2);
        if (dice1 == dice2) {
            snake = true;
        }
    }

    function beginMove() external {
        require(gameID > 0, "No Game Created");
        uint256 currentGameID = addressToGame[msg.sender];
        console.log(idToGameState[currentGameID].currentPlayer, msg.sender);
        require(
            idToGameState[currentGameID].currentPlayer == msg.sender,
            "Must be current Player"
        );

        require(userRoll[msg.sender], "User cannot roll");
        userRoll[msg.sender] = false;
        (bool rollAgain, uint256 stepsFoward) = _rollDice(msg.sender); //We would stop here and wait for chainlink to respnd if using it
        if (userInJail[msg.sender]) {
            if (rollAgain) {
                //User leaves jail
                userInJail[msg.sender] = false;
            }
            stepsFoward = 0;
            rollAgain = false;
        }
        console.log(stepsFoward, rollAgain);
        if (rollAgain) {
            userRoll[msg.sender] = true;
            userRollsRow[msg.sender]++;
            if (userRollsRow[msg.sender] > 3) {
                sendUserToJail(msg.sender);
            }
        }

        _updatePlayerPosition(currentGameID, msg.sender, stepsFoward);
        if (!userRoll[msg.sender]) {
            //As long as the user cannot roll again then progress
            _incrementGameState(currentGameID);
        }
    }

    function _incrementGameState(uint256 _gameID) internal {
        address newPlayer = _getNextPlayer(_gameID);

        console.log("Changing player to", newPlayer);
        address oldCurrentPlayer = idToGameState[_gameID].currentPlayer;
        console.log("player", oldCurrentPlayer, newPlayer);

        require(
            !userRoll[oldCurrentPlayer],
            "can not change while a user can still roll"
        );
        //Change current player
        //Reset their total number of rolls in a  row
        userRollsRow[oldCurrentPlayer] = 0;

        idToGameState[_gameID].currentPlayer = newPlayer;
        // console.log(idToGameState[_gameID].currentPlayer);
        userRoll[newPlayer] = true;
    }

    function _getNextPlayer(
        uint256 _gameID
    ) internal view returns (address newPlayer) {
        address oldCurrentPlayer = idToGameState[_gameID].currentPlayer;
        // console.log("Old player", oldCurrentPlayer);
        uint i = 0;
        for (i = 0; i < idToGameState[_gameID].players.length; i++) {
            // console.log(idToGameState[_gameID].players[i]);
            if (idToGameState[_gameID].players[i] == oldCurrentPlayer) {
                break;
            }
        }
        uint256 nextIndex = (i + 1) % idToGameState[_gameID].players.length;
        //Lets say there are 3 players
        // 3 % 3
        return idToGameState[_gameID].players[nextIndex];
    }

    function testMove(uint256 stepsFoward, bool rollAgain) external {
        require(gameID > 0, "No Game Created");
        uint256 currentGameID = addressToGame[msg.sender];
        // console.log(idToGameState[currentGameID].currentPlayer == msg.sender);
        require(
            idToGameState[currentGameID].currentPlayer == msg.sender,
            "Must be current Player"
        );

        require(userRoll[msg.sender], "User cannot roll");
        userRoll[msg.sender] = false;
        // (bool rollAgain, uint256 steps)//We would stop here and wait for chainlink to respnd if using it
        if (userInJail[msg.sender]) {
            daysInJail[msg.sender]++;
            // console.log(daysInJail[msg.sender]);
            if (rollAgain || daysInJail[msg.sender] >= 2) {
                console.log("User leaves jail");
                //User leaves jail
                userInJail[msg.sender] = false;
            }
            stepsFoward = 0;
            rollAgain = false;
        }

        if (rollAgain) {
            userRoll[msg.sender] = true;
            userRollsRow[msg.sender]++;
            if (userRollsRow[msg.sender] > 3) {
                sendUserToJail(msg.sender);
            }
        }

        _updatePlayerPosition(currentGameID, msg.sender, stepsFoward);
        _incrementGameState(currentGameID);
    }

    // function fulfillRandomness(
    //     bytes32 requestId,
    //     uint256 randomness
    // ) internal override {
    //     randomResult = randomness;
    //     // Add additional logic to handle randomness
    // _updatePlayerPosition(currentGameID, msg.sender, stepsFoward);
    // }

    function _updatePlayerPosition(
        uint256 _gameID,
        address player,
        uint256 stepsFoward
    ) internal {
        if (stepsFoward == 0) {
            return;
        }
        idToGameState[_gameID].playerPosition[player] += stepsFoward;
        if ( idToGameState[_gameID].playerPosition[player] >= MAX_STEPS) {
            emit CrossedGo(player);
            //Need to give the player moneys here!
            SafeERC20.safeTransfer(
                IERC20(idToGameState[_gameID].chosenCurrency),
                player,
                10 * 10 ** 18
            );
            //User arrived at the start
            idToGameState[_gameID].playerPosition[player] -= MAX_STEPS;
        }
        uint256 finalPosition = idToGameState[_gameID].playerPosition[player];
        if (finalPosition == 5) {
            //They are visiitng jail
            emit VisitJail(player);
            return;
        }
        if (finalPosition == 10) {
            //They are getting an air drop
            //Deposit their total number of steps up until that point
            if (1 == 2) {
                emit FoundAsSybil(player);
            } else {
                emit ReceivingAirdrop(player, stepsFoward * 10 ** 17);
                SafeERC20.safeTransfer(
                    IERC20(idToGameState[_gameID].chosenCurrency),
                    player,
                    stepsFoward * 10 ** 17
                );
            }
            return;
        }
        if (finalPosition == 15) {
            sendUserToJail(player);
            return;
        }
        if (finalPosition == 0) {
            return;
        }
        console.log("RE", rentExists[finalPosition], finalPosition);
        if (rentExists[finalPosition]) {
            //Rent exists on this point, take money
            Property activeProp = getProperty(finalPosition);
            uint256 baseRent = activeProp.getBaseRent(finalPosition) * 10 ** 16;
            address[] memory userList = idToGameState[_gameID].players;

            for (uint i = 0; i < userList.length; i++) {
                if (activeProp.balanceOf(userList[i]) > 0) {
                    //The user has money
                    uint256 userRent = (baseRent *
                        activeProp.balanceOf(userList[i])) /
                        activeProp.totalSupply();
                    if (
                        IERC20(idToGameState[_gameID].chosenCurrency).balanceOf(
                            player
                        ) < userRent
                    ) {
                        emit UserLose(player);
                        _removePlayer(player);
                        return;
                    }
                    SafeERC20.safeTransferFrom(
                        IERC20(idToGameState[_gameID].chosenCurrency),
                        player,
                        address(this),
                        userRent
                    );
                    SafeERC20.safeTransfer(
                        IERC20(idToGameState[_gameID].chosenCurrency),
                        userList[i],
                        userRent
                    );
                    emit RentPaid(player, userRent);
                    console.log("Transfer funds", userRent);
                }
            }
        }
    }

    function addNames(string[] memory list) public {
        require(list.length % 2 == 0, "Must be even");
        require(list.length > 0, "Must have stuff ");
        usualNamesAndSymbols = list;
    }

    function _removePlayer(address player) public {
        uint256 currentGame = addressToGame[player];
        uint256 playerIndex = idToGameState[currentGame].numberOfPlayers; // Set to an invalid index initially

        // Find the index of the player in the array
        for (uint i = 0; i < idToGameState[currentGame].players.length; i++) {
            if (idToGameState[currentGame].players[i] == player) {
                playerIndex = i;
                break;
            }
        }

        require(
            playerIndex < idToGameState[currentGame].numberOfPlayers,
            "Player not found"
        );

        // Shift the elements to the left to fill the gap
        for (
            uint i = playerIndex;
            i < idToGameState[currentGame].players.length - 1;
            i++
        ) {
            idToGameState[currentGame].players[i] = idToGameState[currentGame]
                .players[i + 1];
        }

        // Remove the last element (now a duplicate)
        idToGameState[currentGame].players.pop();

        // Decrement the number of players
        console.log(idToGameState[currentGame].players.length);
        idToGameState[currentGame].numberOfPlayers--;
        console.log(idToGameState[currentGame].players.length);
        if (idToGameState[currentGame].players.length == 1) {
            //A player can win
            emit PlayerWon(
                player,
                IERC20(idToGameState[currentGame].chosenCurrency).balanceOf(
                    address(this)
                )
            );

            SafeERC20.safeTransfer(
                IERC20(idToGameState[currentGame].chosenCurrency),
                player,
                IERC20(idToGameState[currentGame].chosenCurrency).balanceOf(
                    address(this)
                )
            );
        }
    }

    function getProperty(uint256 position) public view returns (Property prop) {
        Property[] memory list = getActiveProperties();
        for (uint i = 0; i < list.length; i++) {
            if (list[i].canUserPurchase(position)) {
                return list[i];
            }
        }
        return Property(address(0));
    }

    function purchaseProperty(
        uint256 amountToSpend,
        address property
    ) public returns (uint256) {
        uint256 currentGameID = addressToGame[msg.sender];
        PoolKey memory pk = addressToKey[property];

        //Assume that the currency is token0 and the property is token1
        bool zeroForOne = true;
        uint160 sqrtPriceLimit = 1461446703485210103287273052203988822378723970342;

        if (property < idToGameState[currentGameID].chosenCurrency) {
            zeroForOne = false;
            sqrtPriceLimit = 4295128740;
        }
        int256 amountSpecified = int256(amountToSpend);
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams(
            zeroForOne,
            amountSpecified,
            sqrtPriceLimit
        );
        SafeERC20.safeTransferFrom(
            IERC20(idToGameState[currentGameID].chosenCurrency),
            msg.sender,
            address(this),
            amountToSpend
        );
        // console.log("Game", address(this));
        SafeERC20.forceApprove(
            IERC20(idToGameState[currentGameID].chosenCurrency),
            address(mainHook),
            amountToSpend + 1
        );

        (int256 amount0, int256 amount1) = mainHook.swap(
            pk,
            params,
            block.timestamp + 100,
            msg.sender
        );
        uint256 currentPosition = getPlayerPosition(msg.sender);
        console.log("Property purchased", currentPosition);
        rentExists[currentPosition] = true;

        SafeERC20.safeTransfer(
            IERC20(property),
            msg.sender,
            IERC20(property).balanceOf(address(this))
        );
    }

    function sellProperty(
        uint256 amountToSell,
        address property
    ) public returns (uint256) {
        uint256 currentGameID = addressToGame[msg.sender];
        PoolKey memory pk = addressToKey[property];

        //Assume that the currency is token0 and the property is token1
        bool zeroForOne = false;
        uint160 sqrtPriceLimit = 1461446703485210103287273052203988822378723970342;

        if (property < idToGameState[currentGameID].chosenCurrency) {
            zeroForOne = true;
            sqrtPriceLimit = 4295128740;
        }
        int256 amountSpecified = int256(amountToSell);

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams(
            zeroForOne,
            amountSpecified,
            sqrtPriceLimit
        );
        SafeERC20.safeTransferFrom(
            IERC20(property),
            msg.sender,
            address(this),
            amountToSell
        );
        // console.log("Game", address(this));
        SafeERC20.safeApprove(
            IERC20(property),
            address(mainHook),
            amountToSell
        );

        (int256 amount0, int256 amount1) = mainHook.swap(
            pk,
            params,
            block.timestamp + 100,
            msg.sender
        );
        uint256 amountOwed = 0;
        if (amount0 < 0) {
            amountOwed = uint256(-1 * amount0);
        }
        if (amount1 < 0) {
            amountOwed = uint256(-1 * amount1);
        }
        uint256 currentPosition = getPlayerPosition(msg.sender);
        address[] memory userList = idToGameState[currentGameID].players;

        rentExists[currentPosition] = false;
        for (uint i = 0; i < userList.length; i++) {
            if (Property(property).balanceOf(userList[i]) > 0) {
                rentExists[currentPosition] = true;
            }
        }

        SafeERC20.safeTransfer(
            IERC20(idToGameState[currentGameID].chosenCurrency),
            msg.sender,
            amountOwed
        );
    }

    mapping(address => uint256) public daysInJail;
    mapping(address => bool) public userInJail;

    function sendUserToJail(address user) public {
        emit SentToJail(user);
        daysInJail[msg.sender] = 0;
        userInJail[user] = true;
    }

    function getMyPosition() public view returns (uint256) {
        return getPlayerPosition(msg.sender);
    }

    function getMyProperties() public view returns (Property[] memory) {
        Property[] memory list = getActiveProperties();
        uint count = 0;

        // First pass: count properties owned by the sender
        for (uint i = 0; i < list.length; i++) {
            if (list[i].balanceOf(msg.sender) > 0) {
                count++;
            }
        }

        // Initialize a new array with the correct size
        Property[] memory newList = new Property[](count);
        uint index = 0;

        // Second pass: populate the array
        for (uint i = 0; i < list.length; i++) {
            if (list[i].balanceOf(msg.sender) > 0) {
                newList[index] = list[i];
                index++;
            }
        }

        return newList;
    }

    function getBalanceOfProperty(Property prop) public view returns (uint256) {
        return prop.balanceOf(msg.sender);
    }

    function getAllProperties() public view returns (string[] memory list) {
        return usualNamesAndSymbols;
    }

    function getActiveProperties()
        public
        view
        returns (Property[] memory list)
    {
        if (gameID == 0) {
            revert("No game yet");
        }
        uint256 currentGameID = gameID - 1;
        return idToGameState[currentGameID].propertyList;
    }

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

    function getCurrentPlayer() public view returns (address player) {
        if (gameID == 0) {
            return address(0);
        }
        uint256 currentGameID = gameID - 1;
        return idToGameState[currentGameID].currentPlayer;
    }

    function returnPropertyUnderPlayer(
        address player
    ) public view returns (address) {
        uint256 currentGameID = addressToGame[player];
        uint256 positon = getPlayerPosition(player);

        for (
            uint256 i = 0;
            i < idToGameState[currentGameID].propertyList.length;
            i++
        ) {
            Property property = idToGameState[currentGameID].propertyList[i];
            if (property.canUserPurchase(positon)) {
                return address(property);
            }
        }
        return address(0);
    }

    function getPlayerPosition(
        address user
    ) public view returns (uint256 position) {
        if (gameID == 0) {
            return 0;
        }
        uint256 currentGameID = gameID - 1;
        return idToGameState[currentGameID].playerPosition[user];
    }

    function getBankBalance() public view returns (uint256 balance) {
        if (gameID == 0) {
            return 0;
        }
        uint256 currentGameID = gameID - 1;
        return
            IERC20(idToGameState[currentGameID].chosenCurrency).balanceOf(
                address(this)
            );
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
