const { network, ethers } = require("hardhat");
const { verify } = require("../utils/verify");
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  console.log("Your Chain ID:", chainId);

  log("------------------------------------------------------------");
  let args = [];

  const timeStamp = (await ethers.provider.getBlock("latest")).timestamp;
  args = [500000];

  const PoolManager = await deploy("PoolManager", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });
  if (chainId != 31337 && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...");
    await verify(
      HookFactory.address,
      args,
      "contracts/Uniswap/V4-Core/PoolManager.sol:PoolManager"
    );
  }
  // args = [PoolManager.address];
  // const UniswapInteract = await deploy("UniswapInteract", {
  //   from: deployer,
  //   args: args,
  //   log: true,
  //   blockConfirmations: 2,
  // });
  // // if (chainId != 31337 && process.env.ETHERSCAN_API_KEY) {
  // //   log("Verifying...");
  // //   await verify(
  // //     Router.address,
  // //     args,
  // //     "contracts/UniswapInteract.sol:UniswapInteract"
  // //   );
  // // }

  args = [];
  const HookFactory = await deploy("UniswapHooksFactory", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });

  console.log("Chain", chainId);
  if (chainId != 31337 && process.env.ETHERSCAN_API_KEY) {
    log("Verifying...");
    await verify(
      HookFactory.address,
      args,
      "contracts/Utils/HooksFactory.sol:UniswapHooksFactory"
    );
  }
};
module.exports.tags = ["all", "Need", "Local"];
