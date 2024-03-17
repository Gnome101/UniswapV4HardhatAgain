const { ethers } = require("hardhat");
async function main() {
  const Game = await ethers.getContract("Game");
  await Game.setUp(Game.runner.address, Game.runner.address, 0);
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
