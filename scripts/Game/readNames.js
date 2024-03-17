const { ethers } = require("hardhat");
async function main() {
  const Game = await ethers.getContract("Game");
  const l = await Game.getAllProperties();
  console.log(l);
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
