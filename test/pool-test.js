const { ethers } = require("hardhat");
const { assert } = require("chai");
const { calculateSqrtPriceX96 } = require("../utils/uniswapTools");
const Big = require("big.js");
const { hexlify } = require("ethers");
const {
  setBlockGasLimit,
  time,
} = require("@nomicfoundation/hardhat-network-helpers");
describe("Pool Test ", async function () {
  let poolManager;
  let GNOME;
  let EPICDAI;
  let StringHelper;
  let uniswapInteract;
  let hookFactory;
  beforeEach(async () => {
    accounts = await ethers.getSigners(); // could also do with getNamedAccounts
    deployer = accounts[0];
    user = accounts[1];
    await deployments.fixture(["Local"]);
    poolManager = await ethers.getContract("PoolManager");
    GNOME = await ethers.getContract("GNOME");
    await GNOME.mint();
    await GNOME.mint();
    await GNOME.mint();

    EPICDAI = await ethers.getContract("EPICDAI");
    await EPICDAI.mint();
    await EPICDAI.mint();
    await EPICDAI.mint();

    uniswapInteract = await ethers.getContract("UniswapInteract");
    hookFactory = await ethers.getContract("UniswapHooksFactory");
    StringHelper = await ethers.getContract("StringHelper");
  });
  it("all contracts deployed", async () => {
    // console.log("White ");
  });

  it("can initialze my own pool with no hooks", async () => {
    //Using no hook for this test
    const hook = "0x0000000000000000000000000000000000000000";

    const addresses = [EPICDAI.target, GNOME.target];
    //Make sure that addresses are sorted!
    addresses.sort();

    //Create the pool key
    const poolKey = {
      currency0: addresses[0].toString().trim(),
      currency1: addresses[1].toString().trim(),
      fee: "3000",
      tickSpacing: "60",
      hooks: hook,
    };
    //Calculate the starting price with (price, decimals in token0, decimals in token1)
    const sqrtPrice = calculateSqrtPriceX96(1, 18, 18);
    let timeStamp = (await ethers.provider.getBlock("latest")).timestamp;

    await uniswapInteract.startPool(
      poolKey,
      sqrtPrice.toFixed(),
      "0x",
      timeStamp + 100
    );
    //Below the bounds are defined for the position
    const lowerBound = 0 - 60 * 10;
    const upperBound = 0 + 60 * 10;

    const ModifyPositionParams = {
      tickLower: lowerBound,
      tickUpper: upperBound,
      liquidityDelta: "10000000",
    };

    const poolID = await uniswapInteract.getID(poolKey);
    let liq = await poolManager.getLiquidity(poolID);
    console.log(`The pool is starting with ${liq.toString()} in liquidity`);
    const slot0 = await poolManager.getSlot0(poolID);
    console.log(`Starting tick is ${slot0[1].toString()}`);

    //This is needed to account for the 18 decimals used in ERC20s
    const decimalAdj = new Big(10).pow(18);

    //Below an arbitary amount is set for the token0 and token1 amounts for liquidity
    const token0Amount = new Big("10000").times(decimalAdj);
    const token1Amount = new Big("10000").times(decimalAdj);

    //This is needed to calculate the correct change in liquidity from the token amounts
    const liquidity = await uniswapInteract.getLiquidityAmount(
      slot0[1].toString(),
      lowerBound,
      upperBound,
      token0Amount.toFixed(),
      token1Amount.toFixed()
    );

    ModifyPositionParams.liquidityDelta = liquidity.toString();

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await GNOME.approve(uniswapInteract.target, token0Amount.toFixed());
    await EPICDAI.approve(uniswapInteract.target, token1Amount.toFixed());
    console.log(`Adding liquidity...`);
    //The poolKey is used to identify the pair and the timeStamp + 100 is the deadline
    await uniswapInteract.addLiquidity(
      poolKey,
      ModifyPositionParams,
      timeStamp + 100
    );
    console.log(`Liquidity added!`);
    liq = await poolManager.getLiquidity(poolID);
    console.log(`The pool now has ${liq.toString()} in liquidity`);
    const swapAmount = new Big("10").times(decimalAdj);
    //Below are the neccessary sqrtPriceLimitX96's to set if you want to ignore slippage for a swap

    //zeroForOne - true - 4295128740
    //zeroForOne - false - 1461446703485210103287273052203988822378723970342
    const SwapParams = {
      zeroForOne: true,
      amountSpecified: swapAmount.toFixed(),
      sqrtPriceLimitX96: "4295128740",
    };

    //We are swapping token0 for token1 so we must see which token is which
    let Token0 = EPICDAI.target < GNOME.target ? EPICDAI : GNOME;
    let Token1 = EPICDAI.target < GNOME.target ? GNOME : EPICDAI;

    let token0BalBefore = await Token0.balanceOf(deployer.address);
    token0BalBefore = new Big(token0BalBefore.toString());

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await Token0.approve(uniswapInteract.target, swapAmount.toFixed());
    await Token1.approve(uniswapInteract.target, 0);
    console.log(`Swapping Gnome --> EpicDai`);
    await uniswapInteract.swap(poolKey, SwapParams, timeStamp + 100);
    console.log(`Swap finished!\n`);

    let token0BalAfter = await Token0.balanceOf(deployer.address);
    token0BalAfter = new Big(token0BalAfter.toString());

    assert.equal(
      token0BalBefore.toFixed(),
      token0BalAfter.add(swapAmount).toFixed()
    );

    const token0Donation = new Big("10").times(decimalAdj);
    const token1Donation = new Big("10").times(decimalAdj);

    //With the UniswapInteract code, one must approve of the token and amount beforehand
    await EPICDAI.approve(uniswapInteract.target, token0Donation.toFixed());
    await GNOME.approve(uniswapInteract.target, token1Donation.toFixed());

    console.log(`Donating towards the pool...`);
    await uniswapInteract.donate(
      poolKey,
      token0Donation.toFixed(),
      token1Donation.toFixed(),
      timeStamp + 100
    );
    console.log(`Donation finished!`);
    console.log(`Closing position...`);
    await uniswapInteract.closePosition(
      poolKey,
      lowerBound,
      upperBound,
      timeStamp + 100
    );
    console.log(`Position closed`);
    liq = await poolManager.getLiquidity(poolID);

    console.log(`The pool now has ${liq.toString()} in liquidity`);
  });

  describe("Testing Custom Curve", async () => {
    beforeEach(async () => {
      console.log("Setting up stuff");
    });
    it("can initialze my own pool with custom smurve", async () => {
      console.log(`\nStarting custom pool test!`);
      //I need key, sqrtPrice, and hookData
      const decimalAdj = new Big(10).pow(18);

      const hook = await hookFactory.hooks(0); //This is the hook created in 01-find-hook.js
      const hookContract = await ethers.getContractAt("MyHook", hook);

      //Sort the tokens
      const addresses = [EPICDAI.target, GNOME.target];
      addresses.sort();

      //Use these flags if you wish to include that fee

      //All fees are currently included
      const myFees = 0; //To set protocl fees it mus be done here

      const poolKey = {
        currency0: addresses[0].toString().trim(),
        currency1: addresses[1].toString().trim(),
        fee: myFees,
        tickSpacing: "60",
        hooks: hook,
      };
      const sqrtPrice = calculateSqrtPriceX96(1, 18, 18);

      let timeStamp = (await ethers.provider.getBlock("latest")).timestamp;

      await hookContract.startPool(
        poolKey,
        sqrtPrice.toFixed(),
        "0x",
        timeStamp + 100
      );
      const lowerBound = 0 - 60 * 10;
      const upperBound = 0 + 60 * 10;

      const poolID = await uniswapInteract.getID(poolKey);
      let liq = await poolManager.getLiquidity(poolID);
      console.log(`The pool is starting with ${liq.toString()} in liquidity`);
      const slot0 = await poolManager.getSlot0(poolID);
      console.log(`Starting tick is ${slot0[1].toString()}`);
      const swapAmount = new Big("10").times(decimalAdj);

      //Below we are adding liquidity to hook
      await GNOME.transfer(hook, swapAmount.toFixed());
      await EPICDAI.transfer(hook, swapAmount.toFixed());

      //This is needed to account for the 18 decimals used in ERC20s
      //Below are the neccessary sqrtPriceLimitX96's to set if you want to ignore slippage for a swap

      //zeroForOne - true - 4295128740
      //zeroForOne - false - 1461446703485210103287273052203988822378723970342
      const SwapParams = {
        zeroForOne: true,
        amountSpecified: swapAmount.toFixed(),
        sqrtPriceLimitX96: "4295128740",
      };

      //We are swapping token0 for token1 so we must see which token is which
      let Token0 = EPICDAI.target < GNOME.target ? EPICDAI : GNOME;
      let Token1 = EPICDAI.target < GNOME.target ? GNOME : EPICDAI;

      let token0BalBefore = await Token0.balanceOf(deployer.address);
      token0BalBefore = new Big(token0BalBefore.toString());

      let token1BalBefore = await Token1.balanceOf(deployer.address);
      token1BalBefore = new Big(token1BalBefore.toString());
      //With the UniswapInteract code, one must approve of the token and amount beforehand
      await Token0.approve(hookContract.target, swapAmount.toFixed());
      await Token1.approve(hookContract.target, 0);
      console.log(`Swapping Gnome --> EpicDai`);

      await hookContract.swap(poolKey, SwapParams, timeStamp + 100);
      console.log(`Swap finished!\n`);

      let token0BalAfter = await Token0.balanceOf(deployer.address);
      token0BalAfter = new Big(token0BalAfter.toString());

      let token1BalAfter = await Token1.balanceOf(deployer.address);
      token1BalAfter = new Big(token1BalAfter.toString());

      assert.equal(
        token0BalBefore.toFixed(),
        token0BalAfter.add(swapAmount).toFixed()
      );

      assert.equal(
        token1BalBefore.add(swapAmount).toFixed(),
        token1BalAfter.toFixed()
      );
    });
  });
});
