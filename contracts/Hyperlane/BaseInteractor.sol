// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IMailbox} from "./Interfaces/IMailBox.sol";

contract MessageSender {
    uint32 thisDomain;
    uint32 lukeDomain;
    uint32 arbSepDomain;

    address thisMailBox;
    address lukeMailBox;
    address arbSepMailBox;

    address lukeGame;
    address randArbSep;

    constructor() {}

    function sendMessage() public {
        // quote sending message from alfajores to fuji TestRecipient
        IMailbox mailbox = IMailbox(thisMailBox);
        uint32 destination = 43113;

        bytes32 recipient = addressToBytes32(lukeGame);
        bytes memory body = bytes("Hello, world");
        uint256 fee = mailbox.quoteDispatch(destination, recipient, body);
        mailbox.dispatch{value: fee}(destination, recipient, body);
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
