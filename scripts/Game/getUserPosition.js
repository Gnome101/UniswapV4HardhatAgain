const { ethers } = require("hardhat");
async function main() {
  const Game = await ethers.getContract("Game");
  const position = await Game.getPlayerPosition(Game.runner.address);
  console.log("Position", position);
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
