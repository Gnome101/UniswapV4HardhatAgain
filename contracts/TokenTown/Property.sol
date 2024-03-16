// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Property is ERC20 {
    mapping(address => uint256) userToHouse; //This records how many houses a user has
    address immutable theBank;

    constructor(string memory name, string memory symb) ERC20(name, symb) {
        _mint(msg.sender, 4 * 10 ** 18);
        theBank = msg.sender;
    }

    modifier onlyBank() {
        require(msg.sender == theBank);
        _;
    }

    function addHouse(address user) public onlyBank {
        userToHouse[user]++;
    }
}
