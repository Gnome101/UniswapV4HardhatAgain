const { ethers } = require("hardhat");
async function main() {
  const Game = await ethers.getContract("Game");
  const messageCount = await Game.messageCount();
  console.log("Message count", messageCount);
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
