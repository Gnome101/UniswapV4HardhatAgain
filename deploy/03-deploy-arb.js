const { network } = require("hardhat");
const { verify } = require("../utils/verify");
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;

  log("------------------------------------------------------------");

  args = [];
  const ArbRandom = await deploy("ArbRandom", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });
  if (chainId != 31337) {
    log("Verifying...");
    await verify(
      ArbRandom.address,
      args,
      "contracts/Hyperlane/ArbRandom.sol:ArbRandom"
    );
  }
};
module.exports.tags = ["all", "Arb", "Local"];
