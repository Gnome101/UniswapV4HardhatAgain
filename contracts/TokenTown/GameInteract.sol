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

import {IInterchainSecurityModule} from "../Hyperlane/NullISM.sol";
import {IMailbox} from "../Hyperlane/Interfaces/IMailBox.sol";

contract GameInteract is IGame /*, VRFConsumerBaseV2*/ {
    address public ism = 0x0AbFa98909fC49a3629256441c801203F806cb74;
    uint32 thisDomain;
    uint32 lukeDomain;
    uint32 arbSepDomain;

    address thisMailBox;
    address lukeMailBox;
    address arbSepMailBox;

    address lukeGame;
    address randArbSep;

    struct TokenInfo {
        uint8[4] priceStarts;
        uint8[4] priceChanges;
        uint256 userStart;
    }
    mapping(address => PoolKey) addressToKey;

    constructor(address _poolManager, address _mainHook) {}

    function setISM(address im) external {
        ism = im;
    }

    //Function for testing
    function reclaimTokens(address token) external {
        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    // Implementing the start function from IGame
    function setUp(
        address activeUser,
        address selectedToken,
        uint256 bankStart
    ) public {
        bytes memory data = abi.encode(selectedToken, bankStart);
        bytes memory package = abi.encode(activeUser, 0, data);
        sendMessage(lukeGame, lukeDomain, package);
    }

    function joinGame(address activeUser) public {
        bytes memory data = abi.encode("N");
        bytes memory package = abi.encode(activeUser, 1, data);
        sendMessage(lukeGame, lukeDomain, package);
    }

    function startGame(address activeUser) public {
        bytes memory data = abi.encode("N");
        bytes memory package = abi.encode(activeUser, 2, data);
        sendMessage(lukeGame, lukeDomain, package);
    }

    // function beginMove(address activeUser) public {}

    function testMove(
        address activeUser,
        uint256 stepsFoward,
        bool rollAgain
    ) public {
        bytes memory data = abi.encode(stepsFoward, rollAgain);
        bytes memory package = abi.encode(activeUser, 4, data);
        sendMessage(lukeGame, lukeDomain, package);
    }

    // function fulfillRandomness(
    //     bytes32 requestId,
    //     uint256 randomness
    // ) internal override {
    //     randomResult = randomness;
    //     // Add additional logic to handle randomness
    // _updatePlayerPosition(currentGameID, activeUser, stepsFoward);
    // }

    function purchaseProperty(
        address activeUser,
        uint256 amountToSpend,
        address property
    ) public returns (uint256) {
        bytes memory data = abi.encode(amountToSpend, property);
        bytes memory package = abi.encode(activeUser, 5, data);
        sendMessage(lukeGame, lukeDomain, package);
    }

    function sellProperty(
        address activeUser,
        uint256 amountToSell,
        address property
    ) public returns (uint256) {
        bytes memory data = abi.encode(amountToSell, property);
        bytes memory package = abi.encode(activeUser, 6, data);
        sendMessage(lukeGame, lukeDomain, package);
    }

    uint256 public messageCount;
    address currentUser;

    function rollDice() public {
        currentUser = msg.sender;
        bytes memory data = abi.encode("Helllo");
        sendMessage(randArbSep, arbSepDomain, data);
    }

    // Hyperlane functions
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external payable {
        messageCount++;
        (uint256 dice1, uint256 dice2) = abi.decode(
            _message,
            (uint256, uint256)
        );
        bool snake = false;
        if (dice1 == dice2) {
            snake = true;
        }
        testMove(currentUser, dice1 + dice2, snake);
    }

    function sendMessage(
        address to,
        uint32 toDomain,
        bytes memory data
    ) public {
        // quote sending message from alfajores to fuji TestRecipient
        IMailbox mailbox = IMailbox(thisMailBox);
        uint32 destination = toDomain;

        bytes32 recipient = addressToBytes32(to);
        // bytes memory body = bytes("Hello, world");
        uint256 fee = mailbox.quoteDispatch(destination, recipient, data);
        mailbox.dispatch{value: fee}(destination, recipient, data);
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function interchainSecurityModule()
        external
        view
        returns (IInterchainSecurityModule)
    {
        return IInterchainSecurityModule(ism);
    }
}
