const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Raffler", function () {
  let account;
  let traff;
  let rafflable;
  let raffler;

  before(async () => {
    const [signer] = await ethers.getSigners();
    account = signer.address;
    const Raffler = await ethers.getContractFactory("Raffler");
    const TRAFF = await ethers.getContractFactory("TRAFF");
    traff = await TRAFF.deploy();
    raffler = await Raffler.deploy(account, traff.address, '1000000'); // 1 TRAFF
    await raffler.deployed();
    await traff.deployed();
    const tx = await traff.faucet(); // Credit 1000 TRAFF
    await tx.wait();
  });

  it("Draw a winner", async function () {
    for (let i = 1; i <= 10; i++) {
      const counter = await raffler.counter();
      console.log("draw #",counter);
      console.log("winners:",await raffler.winners());
      console.log("hat:",await raffler.hat());
      await raffler.add(i, i);
      console.log("hat:",await raffler.hat());
      await traff.transfer(raffler.address, '1000000'); // 1 TRAFF
      await raffler.draw('0x844a5d090b8c04699e3ae379a5261c0d344737b6d0ffee100abda2437561419b');
	  console.log("winners (after):",await raffler.winners());
    }
    console.log(await raffler.hatOf(0));  
    console.log(await raffler.hatOf(1));  
    console.log(await raffler.hatOf(2));  
    console.log(await raffler.hatOf(3));  
    console.log(await raffler.hatOf(4));  
  });
});
