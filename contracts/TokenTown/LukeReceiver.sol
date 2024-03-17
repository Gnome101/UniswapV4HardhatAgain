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
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Custom} from "../Mocks/Custom.sol";
import {Game} from "./Game.sol";

contract LukeRecieve {
    address public ism = 0x1F02fA4F142e0727CC3f2eC84433aB513F977657;
    Game public game;

    constructor(address _game) {
        game = Game(_game);
        // You can use console.log for debugging purposes
        // console.log("Game contract deployed by:", activeUser);
        // console.log("Pool Manager set to:", poolManager);
    }

    uint256 public messageCount = 0;

    // Hyperlane functions
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _message
    ) external payable {
        messageCount++;
        (address user, uint256 action, bytes memory data) = abi.decode(
            _message,
            (address, uint256, bytes)
        );

        if (action == 0) {
            // console.log("Action 0");
            //setUp()
            (address selToken, uint256 bankStart) = abi.decode(
                data,
                (address, uint256)
            );
            game.setUp(user, selToken, bankStart);
        } else if (action == 1) {
            game.joinGame(user);
        } else if (action == 2) {
            // console.log("Action 2");
            //startGame()
            game.startGame(user);
        } else if (action == 3) {} else if (action == 4) {
            // console.log("Action 4");
            (uint256 steps, bool snake) = abi.decode(data, (uint256, bool));
            game.testMove(user, steps, snake);
        } else if (action == 5) {
            // console.log("Action 5");
            (uint256 amount, address property) = abi.decode(
                data,
                (uint256, address)
            );
            game.purchaseProperty(user, amount, property);
            //purchaseProperty()
        } else if (action == 6) {
            // console.log("Action 6");
            (uint256 amount, address property) = abi.decode(
                data,
                (uint256, address)
            );
            game.sellProperty(user, amount, property);

            //sellProperty()
        } else if (action == 7) {
            // console.log("Action 7");
        } else {
            // console.log("Not real");
        }
    }

    function interchainSecurityModule()
        external
        view
        returns (IInterchainSecurityModule)
    {
        return IInterchainSecurityModule(ism);
    }
}
