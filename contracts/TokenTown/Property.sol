// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract Property is ERC20 {
    mapping(address => uint256) userToHouse; //This records how many houses a user has
    address immutable theBank;

    uint256 position; //Marks the start
    uint256 priceStart = 0;
    uint256 rentStart = 0;
    uint256 priceIncrease = 0;
    uint256 length = 4;

    constructor(
        string memory name,
        string memory symb,
        uint256 supply,
        uint256 _position,
        uint256 _price,
        uint256 _rent,
        uint256 _increase
    ) ERC20(name, symb) {
        _mint(msg.sender, supply * 10 ** 18);
        // console.log("set token", _price, _increase);
        theBank = msg.sender;
        position = _position;
        priceStart = _price;
        rentStart = _rent;
        priceIncrease = _increase;
    }

    modifier onlyBank() {
        require(msg.sender == theBank);
        _;
    }

    function addHouse(address user) public onlyBank {
        userToHouse[user]++;
    }

    function getBaseRent(
        uint256 playerPoint
    ) public view returns (uint256 rent) {
        uint256 amountAfter = playerPoint - position;
        rent = rentStart + priceIncrease * amountAfter;
        console.log(rentStart, priceIncrease, amountAfter);
        return rent;
    }

    function getPrice(uint256 playerPoint) public view returns (uint256 price) {
        uint256 amountAfter = playerPoint - position;
        price = priceStart + priceIncrease * amountAfter;
        console.log(priceStart, priceIncrease, amountAfter);
        return price;
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
