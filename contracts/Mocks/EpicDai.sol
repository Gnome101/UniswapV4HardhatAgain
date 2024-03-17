// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EPICDAI is ERC20 {
    constructor() ERC20("EPICAI", "EDAI") {
        //Uncomment to mint upon deployment
        _mint(msg.sender, 10 * 10 ** 18);
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
