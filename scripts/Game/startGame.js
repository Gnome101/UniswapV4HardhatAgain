const { ethers } = require("hardhat");
async function main() {
  const GameInteract = await ethers.getContract("GameInteract");
  await GameInteract.startGame(GameInteract.runner.address);
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
