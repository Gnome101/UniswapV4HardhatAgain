// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;
// import "hardhat/console.sol";

// contract StringHelper {
//     // This bytes array should contain the encoded string data
//     bytes constant names =
//         hex"000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000000b4765726d616e20526f61640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010436861696e6c696e6b204176656e756500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f46696c65636f696e205374726565740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f48797065726c616e6520416c6c657900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009426f61726477616c6b0000000000000000000000000000000000000000000000";

//     // Function to decode a string from the provided bytes at a given offset
//     function getStringAtOffset(
//         bytes memory data,
//         uint256 offset
//     ) internal pure returns (string memory) {
//         // Decoding the length of the string
//         uint256 length;
//         assembly {
//             length := mload(add(data, add(offset, 0x20)))
//         }
//         // Extracting the string of the given length
//         bytes memory extractedString = new bytes(length);
//         for (uint256 i = 0; i < length; i++) {
//             extractedString[i] = data[offset + i + 0x20];
//         }
//         return string(extractedString);
//     }

//     // Function to loop through the encoded strings and log them
//     function loop() public {
//         // Decoding the number of strings (first 32 bytes)
//         uint256 numberOfStrings;
//         assembly {
//             numberOfStrings := mload(add(names, 0x20))
//         }

//         // Starting offset after the length prefix and number of strings
//         uint256 offset = 0x40;

//         // Iterating over each string
//         for (uint256 i = 0; i < numberOfStrings; i++) {
//             // Decoding the offset for the current string
//             uint256 stringOffset;
//             assembly {
//                 stringOffset := mload(add(names, add(offset, mul(i, 0x20))))
//             }
//             // Extracting and logging the string
//             string memory name = getStringAtOffset(names, stringOffset + 0x20); // Adding base offset
//             console.log(name);
//         }
//     }
// }
