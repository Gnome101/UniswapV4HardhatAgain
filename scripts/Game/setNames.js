const { ethers } = require("hardhat");
async function main() {
  const Game = await ethers.getContract("Game");
  const list = ["Street", "STR"];
  await Game.addNames(list);
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
