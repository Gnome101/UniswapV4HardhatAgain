// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;
import "../MyHook.sol";
import {IPoolManager} from "../Uniswap/V4-Core/interfaces/IPoolManager.sol";
import {HookMiner} from "./HookerMiner.sol";
import {Hooks} from "../Uniswap/V4-Core/libraries/Hooks.sol";
import "hardhat/console.sol";

contract UniswapHooksFactory {
    address[] public hooks;

    function deploy(address poolManager, bytes32 salt) external {
        // console.log("deploying hooks...");
        hooks.push(address(new MyHook{salt: salt}(IPoolManager(poolManager))));
    }

    function findSalt(
        uint256 start,
        IPoolManager poolManager
    )
        external
        view
        returns (bool works, address finalAddress, bytes32 rightSalt)
    {
        // console.log("deploying hook...");
        uint160 flags = uint160(Hooks.NO_OP_FLAG | Hooks.BEFORE_SWAP_FLAG);

        (bool suc, address addy, bytes32 salt) = HookMiner.find(
            start,
            address(this),
            flags,
            type(MyHook).creationCode,
            abi.encode(poolManager)
        );
        // console.log("Will deploy to", addy);
        return (suc, addy, salt);
    }

    function getPrecomputedHookAddress(
        address /*owner */,
        address poolManager,
        bytes32 salt
    ) external view returns (address) {
        //Creation code + constructor argument
        bytes32 bytecodeHash = keccak256(
            abi.encodePacked(type(MyHook).creationCode, abi.encode(poolManager))
        );
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)
        );
        return address(uint160(uint256(hash)));
    }
}
