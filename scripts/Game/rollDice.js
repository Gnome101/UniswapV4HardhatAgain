const { ethers } = require("hardhat");
async function main() {
  const GameInteract = await ethers.getContract("GameInteract");
  await GameInteract.rollDice();
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
