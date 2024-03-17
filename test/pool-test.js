const { ethers } = require("hardhat");
const { assert, expect } = require("chai");
const { calculateSqrtPriceX96 } = require("../utils/uniswapTools");
const Big = require("big.js");
const { hexlify } = require("ethers");
const {
  setBlockGasLimit,
  time,
} = require("@nomicfoundation/hardhat-network-helpers");
const { deployContract } = require("@nomicfoundation/hardhat-ethers/types");
describe("Pool Test ", async function () {
  let poolManager;
  let GNOME;
  let EPICDAI, userEPICDAI;
  let uniswapInteract;
  let hookFactory;
  let Game;
  beforeEach(async () => {
    accounts = await ethers.getSigners(); // could also do with getNamedAccounts
    deployer = accounts[0];
    user = accounts[1];
    await deployments.fixture(["Local"]);
    poolManager = await ethers.getContract("PoolManager");
    GNOME = await ethers.getContract("GNOME");

    EPICDAI = await ethers.getContract("EPICDAI");
    userEPICDAI = await ethers.getContract("EPICDAI", user);
    hookFactory = await ethers.getContract("UniswapHooksFactory");
    deployerGame = await ethers.getContract("Game");
    userGame = await ethers.getContract("Game", user);
  });
  it("all contracts deployed", async () => {
    // console.log("White ");
  });

  it("can set up game", async () => {
    const chosenToken = EPICDAI;
    const list = [
      "Street",
      "STR",
      "Avenue",
      "AVE",
      "Lane",
      "LNE",
      "Way",
      "WAY",
    ];
    const decimalAdj = new Big(10).pow(18); // Adjust for ERC20 decimals
    const startingAmount = new Big("1000").times(decimalAdj); // Set an arbitrary amount for token

    // Mint and approve tokens for the game
    await chosenToken.mint(startingAmount.toFixed());
    await chosenToken.approve(deployerGame.target, startingAmount.toFixed());

    // Set up the game with the token and check game balance
    await deployerGame.setUp(
      deployer.address,
      chosenToken.target,
      startingAmount.toFixed()
    );
    const gameBalance = await chosenToken.balanceOf(deployerGame.target);
    assert.equal(gameBalance.toString(), startingAmount.toFixed());

    // User attempts to join the game
    await userGame.joinGame(user.address);
    // Add further assertions and game setup checks here
  });
  describe("Testing Game Mechanics", async () => {
    beforeEach(async () => {
      const chosenToken = EPICDAI;
      const list = [
        "Street",
        "STR",
        "Avenue",
        "AVE",
        "Lane",
        "LNE",
        "Way",
        "WAY",
      ];
      const gameID = "0";
      await deployerGame.addNames(list);
      //This is needed to account for the 18 decimals used in ERC20s
      const decimalAdj = new Big(10).pow(18);

      //Below an arbitary amount is set for the token0 and token1 amounts for liquidity
      const startingAmount = new Big("1000").times(decimalAdj);
      console.log(startingAmount.toFixed());
      await chosenToken.mint(startingAmount.toFixed());
      await chosenToken.approve(deployerGame.target, startingAmount.toFixed());
      await deployerGame.setUp(
        deployer.address,
        chosenToken.target,
        startingAmount.toFixed()
      );
      const listSol = await deployerGame.getAllProperties();
      assert.equal(listSol.toString(), list.toString());
      const gameBalance = await chosenToken.balanceOf(deployerGame.target);
      assert(gameBalance.toString(), startingAmount.toFixed());

      //Now the user will attempt to join
      await userGame.joinGame(user.address);

      //Now I validate all properties
      const numOfPlayers = await deployerGame.getActiveNumberOfPlayers();
      assert.equal(numOfPlayers.toString(), "2");

      const activeGameID = await deployerGame.getActiveGameID();
      assert.equal(activeGameID.toString(), "0");

      const activePlayers = await deployerGame.getActivePlayers();
      assert.equal(activePlayers.toString(), [deployer.address, user.address]);

      const chosenCurrency = await deployerGame.getCurrentChosenCurrency();
      assert.equal(chosenCurrency.toString(), chosenToken.target);
      //User joins
      const buyIN = await deployerGame.getBuyIn();
      await userEPICDAI.mint(buyIN.toString());
      await userEPICDAI.approve(userGame.target, buyIN.toString());

      //Now we can start the game

      await deployerGame.startGame(deployer.address);
    });
    it("testing movement", async () => {
      //Show the player moving
      console.log("FIrst");
      await deployerGame.beginMove(deployer.address);
      console.log("FIrst");

      const deployerNewPosition = await deployerGame.getPlayerPosition(
        deployer.address
      );
      console.log("New Deployer Position:", deployerNewPosition.toString());
      assert.isAbove(parseInt(deployerNewPosition.toString()), 0);
      await expect(deployerGame.beginMove(deployer.address)).to.be.revertedWith(
        "Must be current Player"
      );
      console.log("after");
      // console.log("Here", user.address);
      await userGame.beginMove(user.address);
      const userNewPosition = await deployerGame.getPlayerPosition(
        user.address
      );
      console.log("New User Position:", userNewPosition.toString());
      assert.isAbove(parseInt(userNewPosition.toString()), 0);
    });
    it("user can purchase property", async () => {
      //Show the player moving

      await deployerGame.testMove(deployer.address, 2, false);

      //Player is now at the location
      const listOfProperties = await deployerGame.getActiveProperties();
      const deployerNewPosition = await deployerGame.getPlayerPosition(
        deployer.address
      );
      assert.equal(deployerNewPosition.toString(), "2");
      const property = await deployerGame.returnPropertyUnderPlayer(
        deployer.address
      );
      // console.log(property);
      assert.equal(property.toString(), listOfProperties[0]);
      const amount = ethers.parseEther("65");

      await EPICDAI.approve(deployerGame.target, amount.toString());
      await deployerGame.purchaseProperty(
        deployer.address,
        amount.toString(),
        property.toString()
      );
      const list = await deployerGame.getMyProperties(deployer.address);
      const propertyAmount = await deployerGame.getBalanceOfProperty(
        deployer.address,
        list[0]
      );
      assert.equal(
        propertyAmount.toString(),
        ethers.parseEther("1").toString()
      );
      PROP = await ethers.getContractAt("Property", property.toString());
      await PROP.approve(
        deployerGame.target,
        ethers.parseEther("10").toString()
      );
      await deployerGame.sellProperty(
        deployer.address,
        ethers.parseEther("1").toString(),
        property.toString()
      );
    });
    it("rent is enforced", async () => {
      //Show the player moving
      await deployerGame.testMove(deployer.address, 2, false);
      //Player is now at the location
      const listOfProperties = await deployerGame.getActiveProperties();
      console.log(listOfProperties);
      const deployerNewPosition = await deployerGame.getPlayerPosition(
        deployer.address
      );
      assert.equal(deployerNewPosition.toString(), "2");
      const property = await deployerGame.returnPropertyUnderPlayer(
        deployer.address
      );
      // console.log(property);
      assert.equal(property.toString(), listOfProperties[0]);
      console.log("Time to purchase");
      const amount = ethers.parseEther("65");

      await EPICDAI.approve(deployerGame.target, amount.toString());
      await deployerGame.purchaseProperty(
        deployer.address,
        amount.toString(),
        property.toString()
      );
      const list = await deployerGame.getMyProperties(deployer.address);
      const propertyAmount = await deployerGame.getBalanceOfProperty(
        deployer.address,
        list[0]
      );
      console.log("Here");
      await userEPICDAI.approve(deployerGame.target, amount.toString());
      await userGame.testMove(user.address, 2, false);
    });
    it("user can get sent to jail", async () => {
      //Jail is on 6
      await expect(deployerGame.testMove(deployer.address, 15, false)).to.emit(
        deployerGame,
        "SentToJail"
      );
      //If the user is in jail they cannot move
      await userGame.testMove(user.address, 1, false);

      await deployerGame.testMove(deployer.address, 2, false);

      const deployerNewPosition1 = await deployerGame.getPlayerPosition(
        deployer.address
      );
      console.log("New Deployer Position 1:", deployerNewPosition1.toString());
      assert.equal(deployerNewPosition1.toString(), "15");

      await userGame.testMove(user.address, 1, false);
      await deployerGame.testMove(deployer.address, 2, false);

      await userGame.testMove(user.address, 1, false);
      await deployerGame.testMove(deployer.address, 2, false);

      const deployerNewPosition2 = await deployerGame.getPlayerPosition(
        deployer.address
      );
      assert.equal(deployerNewPosition2.toString(), "17");
    });
    it("user can receive air drop", async () => {
      const balBefore = new Big(
        (await EPICDAI.balanceOf(deployer.address)).toString()
      );
      const steps = 10;
      await expect(
        deployerGame.testMove(deployer.address, steps, false)
      ).to.emit(deployerGame, "ReceivingAirdrop");
      const balAfter = new Big(
        (await EPICDAI.balanceOf(deployer.address)).toString()
      );
      const decimal = new Big(10).pow(16);
      const reward = new Big(steps).mul(decimal);
      console.log(balAfter.sub(balBefore).toFixed(), reward.toFixed()); //This shows that the user is receiving the air drop
    });
    it("user can win", async () => {
      const balDEployer = await EPICDAI.balanceOf(deployer.address);
      await EPICDAI.transfer(user.address, balDEployer.toString());

      await deployerGame.testMove(deployer.address, 2, false);

      await userGame.testMove(user.address, 4, false);
      const property = await userGame.returnPropertyUnderPlayer(user.address);
      await userEPICDAI.approve(userGame.target, ethers.parseEther("80"));
      await userGame.purchaseProperty(
        user.address,
        ethers.parseEther("80"),
        property
      );
      console.log("----------------------");
      await expect(deployerGame.testMove(deployer.address, 2, false)).to.emit(
        deployerGame,
        "PlayerWon"
      );
    });
    it("user can receive money from passing go", async () => {
      const balBefore = new Big(
        (await EPICDAI.balanceOf(deployer.address)).toString()
      );
      const steps = 20;
      await expect(
        deployerGame.testMove(deployer.address, steps, false)
      ).to.emit(deployerGame, "CrossedGo");
      const balAfter = new Big(
        (await EPICDAI.balanceOf(deployer.address)).toString()
      );
      const reward = new Big(ethers.parseEther("10").toString());
      assert.equal(balAfter.sub(balBefore).toFixed(), reward.toFixed()); //This shows that the user is receiving the air drop
    });
    // Test case for buying, selling, and rebuying a property
    it("user can buy, sell, and another user can buy the property ", async () => {
      // Show the player moving
      await deployerGame.testMove(deployer.address, 2, false);

      // Player is now at the location
      const listOfProperties = await deployerGame.getActiveProperties();
      const deployerNewPosition = await deployerGame.getPlayerPosition(
        deployer.address
      );
      console.log("New Deployer Position:", deployerNewPosition.toString());
      assert.equal(deployerNewPosition.toString(), "2");
      const property = await deployerGame.returnPropertyUnderPlayer(
        deployer.address
      );
      assert.equal(property.toString(), listOfProperties[0]);

      console.log("Time to purchase");
      const amount = ethers.parseEther("65");
      await EPICDAI.approve(deployerGame.target, amount.toString());
      await deployerGame.purchaseProperty(
        deployer.address,
        amount.toString(),
        property.toString()
      );
      const list = await deployerGame.getMyProperties(deployer.address);
      const propertyAmount = await deployerGame.getBalanceOfProperty(
        deployer.address,
        list[0]
      );
      assert.equal(
        propertyAmount.toString(),
        ethers.parseEther("1").toString()
      );

      PROP = await ethers.getContractAt("Property", property.toString());
      await PROP.approve(
        deployerGame.target,
        ethers.parseEther("10").toString()
      );
      await deployerGame.sellProperty(
        deployer.address,
        ethers.parseEther("1").toString(),
        property.toString()
      );

      console.log("User moving to the property location");
      await userGame.testMove(user.address, 2, false);
      const userNewPosition = await userGame.getPlayerPosition(user.address);
      console.log("New User Position:", userNewPosition.toString());
      assert.equal(userNewPosition.toString(), "2");

      console.log("User purchasing the property");
      await userEPICDAI.approve(userGame.target, amount.toString());
      await userGame.purchaseProperty(
        user.address,
        amount.toString(),
        property.toString()
      );
      const userList = await userGame.getMyProperties(user.address);
      console.log(userList);
      const userPropertyAmount = await userGame.getBalanceOfProperty(
        user.address,
        userList[0]
      );
      console.log(userPropertyAmount.toString());
      assert.equal(
        userPropertyAmount.toString(),
        ethers.parseEther("1").toString()
      );

      console.log("User selling the property");
      await PROP.connect(user).approve(
        userGame.target,
        ethers.parseEther("10").toString()
      );
      await userGame.sellProperty(
        user.address,
        ethers.parseEther("1").toString(),
        property.toString()
      );
    });
  });
});
