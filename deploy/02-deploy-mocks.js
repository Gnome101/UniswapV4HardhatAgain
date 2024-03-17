const { network } = require("hardhat");
const { verify } = require("../utils/verify");
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  log("------------------------------------------------------------");

  args = [];
  const EPICDAI = await deploy("EPICDAI", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });
  //   if (chainId != 31337) {
  //     log("Verifying...");
  //     await verify(EPICDAI.address, args, "contracts/Mocks/EpicDai.sol:EPICDAI");
  //   }
  const GNOME = await deploy("GNOME", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });
  //   if (chainId != 31337) {
  //     log("Verifying...");
  //     await verify(GNOME.address, args, "contracts/Mocks/GNOME.sol:GNOME");
  //   }
  const poolManager = await ethers.getContract("PoolManager");

  const hookFactory = await ethers.getContract("UniswapHooksFactory");

  const hook = await hookFactory.hooks(0); //This is the hook created in 01-find-hook.js
  args = [poolManager.target, hook];
  const Game = await deploy("Game", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });

  const hookContract = await ethers.getContractAt("MyHook", hook);
  await hookContract.setGame(Game.address);
  //   if (chainId != 31337) {
  //     log("Verifying...");
  //     await verify(Game.address, args, "contracts/TokenTown/Game.sol:Game");
  //   }
};
module.exports.tags = ["all", "Tokens", "Local"];
