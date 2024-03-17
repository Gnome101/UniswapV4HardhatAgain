const { network } = require("hardhat");
const { verify } = require("../utils/verify");
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  log("------------------------------------------------------------");

  args = [];
  const GameInteract = await deploy("GameInteract", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });
  if (chainId != 31337) {
    log("Verifying...");
    await verify(
      GameInteract.address,
      args,
      "contracts/TokenTown/GameInteract.sol:GameInteract"
    );
  }
};
module.exports.tags = ["all", "Base", "Local"];
