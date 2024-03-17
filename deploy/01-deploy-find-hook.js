const { network } = require("hardhat");
const { verify } = require("../utils/verify.js");
const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  const owner = deployer;
  const poolManager = await ethers.getContract("PoolManager");
  // const uniswapInteract = await ethers.getContract("UniswapInteract");

  const hookFactory = await ethers.getContract("UniswapHooksFactory");

  //salt is the random number added to the address
  let salt;
  //The final address is the one that matches the correct prefix
  let finalAddress;
  //The desired prefix is set here
  const correctPrefix = 0x001;
  let start = 0;
  for (let i = 0; i < 3; i++) {
    result = await hookFactory.findSalt.staticCall(start, poolManager.target);
    if (result.works) {
      break;
    }
    start += 10000; //add 10,000
  }
  // console.log("Correct salt", result);
  // //The code loops through the salts below
  // // - If the address is not found, increase the length of search( e.g i < 2000) and ensure that prefix is possible

  // for (let i = 0; i < 2000; i++) {
  //   salt = ethers.toBeHex(i);
  //   //console.log(salt);
  //   salt = ethers.zeroPadValue(salt, 32);

  //   let expectedAddress = await hookFactory.getPrecomputedHookAddress(
  //     owner,
  //     poolManager.target,
  //     salt
  //   );
  //   finalAddress = expectedAddress;
  //   //console.log(i, "Address:", expectedAddress);
  //   expectedAddress = expectedAddress;
  //   //This console.log() prints all of the generated addresses
  //   console.log(finalAddress);
  //   if (_doesAddressStartWith(expectedAddress, correctPrefix)) {
  //     console.log("This is the correct salt:", salt);
  //     break;
  //   }
  // }

  // function _doesAddressStartWith(_address, _prefix) {
  //   // console.log(_address.substring(0, 4), ethers.toBeHex(_prefix).toString());
  //   return _address.substring(0, 5) == ethers.toBeHex(_prefix).toString();
  // }
  // console.log("Now deploying");
  // console.log(poolManager.target, result.rightSalt);
  await hookFactory.deploy(poolManager.target, result.rightSalt);
  console.log("Hooks deployed with address:", result.finalAddress);
  console.log("Chain", chainId);
};
module.exports.tags = ["all", "Need", "Local", "luke"];
