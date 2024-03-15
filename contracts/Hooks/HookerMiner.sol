// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.21;
import "hardhat/console.sol";

/// @title HookMiner - a library for mining hook addresses
/// @dev This library is intended for `forge test` environments. There may be gotchas when using salts in `forge script` or `forge create`
library HookMiner {
    // mask to slice out the top 12 bit of the address
    uint160 constant FLAG_MASK = 0xFFF << 148;

    // Maximum number of iterations to find a salt, avoid infinite loops
    uint256 constant MAX_LOOP = 10_000;

    /// @notice Find a salt that produces a hook address with the desired `flags`
    /// @param deployer The address that will deploy the hook. In `forge test`, this will be the test contract `address(this)` or the pranking address
    ///                 In `forge script`, this should be `0x4e59b44847b379578588920cA78FbF26c0B4956C` (CREATE2 Deployer Proxy)
    /// @param flags The desired flags for the hook address
    /// @param creationCode The creation code of a hook contract. Example: `type(Counter).creationCode`
    /// @param constructorArgs The encoded constructor arguments of a hook contract. Example: `abi.encode(address(manager))`
    /// @return hookAddress salt and corresponding address that was found. The salt can be used in `new Hook{salt: salt}(<constructor arguments>)`
    function find(
        uint256 start,
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal view returns (bool, address, bytes32) {
        address hookAddress;
        bytes memory creationCodeWithArgs = abi.encodePacked(
            creationCode,
            constructorArgs
        );

        uint256 salt = start;
        for (salt; salt < MAX_LOOP + start; salt++) {
            hookAddress = computeAddress(deployer, salt, creationCodeWithArgs);
            // console.log(hookAddress, salt);
            if (
                uint160(hookAddress) & FLAG_MASK == flags &&
                hookAddress.code.length == 0
            ) {
                // console.log("Correct");
                return (true, hookAddress, bytes32(salt));
            }
        }
        // revert("HookMiner: could not find salt");
        return (false, address(0), 0x00);
    }

    /// @notice Precompute a contract address deployed via CREATE2
    /// @param deployer The address that will deploy the hook. In `forge test`, this will be the test contract `address(this)` or the pranking address
    ///                 In `forge script`, this should be `0x4e59b44847b379578588920cA78FbF26c0B4956C` (CREATE2 Deployer Proxy)
    /// @param salt The salt used to deploy the hook
    /// @param creationCode The creation code of a hook contract
    function computeAddress(
        address deployer,
        uint256 salt,
        bytes memory creationCode
    ) public pure returns (address hookAddress) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xFF),
                                deployer,
                                salt,
                                keccak256(creationCode)
                            )
                        )
                    )
                )
            );
    }
}
