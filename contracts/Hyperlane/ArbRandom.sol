// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "hardhat/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

import {IInterchainSecurityModule} from "../Hyperlane/NullISM.sol";
import {IMailbox} from "../Hyperlane/Interfaces/IMailBox.sol";

import {VRFV2WrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/VRFV2WrapperConsumerBase.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract ArbRandom is VRFV2WrapperConsumerBase {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    address public ism = 0xc1Bf61B01b00A44aC253Ef66f9de52DAdb99D943;

    uint32 thisDomain;
    uint32 baseSepDomain;

    address thisMailBox;
    address arbSepMailBox;

    address gameInteract;
    struct RequestStatus {
        uint256 paid;
        bool fulfilled;
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests;

    uint256[] public requestIds;
    uint256 public lastRequestId;
    uint32 callbackGasLimit = 400000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 2;
    address linkAddress = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;
    address wrapperAddress = 0x1D3bb92db7659F2062438791F131CFA396dfb592;

    constructor() VRFV2WrapperConsumerBase(linkAddress, wrapperAddress) {}

    // function setISM(address im) external {
    //     ism = im;
    // }

    //Function for testing
    function reclaimTokens(address token) external {
        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    function requestRandomWords() public returns (uint256 requestId) {
        requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );
        s_requests[requestId] = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWords: new uint256[](0),
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    uint256 public msgCount;

    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _data
    ) external payable {
        msgCount++;
        requestRandomWords();
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].paid
        );
        bytes memory data = abi.encode(
            (_randomWords[0] % 12) + 1,
            (_randomWords[1] % 12) + 1
        );
        sendMessage(gameInteract, baseSepDomain, data);
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

    function withdrawLink() public {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
