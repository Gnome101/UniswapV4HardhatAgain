const { ethers } = require("hardhat");
async function main() {
  const GameInteract = await ethers.getContract("GameInteract");
  await GameInteract.setUp(
    GameInteract.runner.address,
    GameInteract.target,
    "0"
  );
}
main().catch((error) => {
  console.error(error);
  process.exit(1);
});
