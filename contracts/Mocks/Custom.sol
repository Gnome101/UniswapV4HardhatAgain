// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Custom is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        //Uncomment to mint upon deployment
        _mint(msg.sender, 1000 * 10 ** 18);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
