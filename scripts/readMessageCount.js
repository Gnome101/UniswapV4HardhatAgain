const { ethers } = require("hardhat");
async function main() {
  const LukeRecieve = await ethers.getContract("LukeRecieve");
  const messageCount = await LukeRecieve.messageCount();
  console.log("Message count", messageCount);
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
