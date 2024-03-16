// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Property is ERC20 {
    mapping(address => uint256) userToHouse; //This records how many houses a user has
    address immutable theBank;

    uint256 position; //Marks the start
    uint256 priceStart = 0;
    uint256 priceIncrease = 0;
    uint256 length = 4;

    constructor(
        string memory name,
        string memory symb,
        uint256 supply,
        uint256 _position,
        uint256 _price,
        uint256 _increase
    ) ERC20(name, symb) {
        _mint(msg.sender, supply * 10 ** 18);
        theBank = msg.sender;
        position = _position;
        priceStart = _price;
        priceIncrease = _increase;
    }

    modifier onlyBank() {
        require(msg.sender == theBank);
        _;
    }

    function addHouse(address user) public onlyBank {
        userToHouse[user]++;
    }

    function canUserPurchase(uint256 userPosition) public view returns (bool) {
        if (position <= userPosition && userPosition <= position + length) {
            return true;
        }
        return false;
    }

    function getPriceStart() public view returns (uint256) {
        return priceStart;
    }

    function getPriceIncrease() public view returns (uint256) {
        return priceIncrease;
    }
}
