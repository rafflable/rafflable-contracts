const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("25 000 tickets, 5 draws", function () {
  let account;
  let traff;
  let rafflable;
  let raffler;

  before(async () => {
    const [signer] = await ethers.getSigners();
    account = signer.address;
    const Rafflable = await ethers.getContractFactory("Rafflable");
    const Raffler = await ethers.getContractFactory("Raffler");
    const TRAFF = await ethers.getContractFactory("TRAFF");

    traff = await TRAFF.deploy();
    rafflable = await Rafflable.deploy('', '', '', '', '25000', 0, account, traff.address, '1000000'); // 1 TRAFF
    raffler = await Raffler.deploy(rafflable.address, traff.address, '500000000'); // 500 TRAFF
    await rafflable.deployed();
    await raffler.deployed();
    await traff.deployed();
    await rafflable.setRaffler(raffler.address);
    for (let i = 0; i < 25; i++) {
      await traff.faucet(); // Credit 1000 TRAFF
    }
    const tx = await traff.approve(rafflable.address, '25000000000'); // 25 000 TRAFF
    await tx.wait();
  });

  for (let i = 0; i <= 25000; i++) {
    if (i == 25000) {
      it("Should have 5 winners", async function () {
        winners = await raffler.winners();
        expect(winners.length).to.be.equal(5);
      });
      it(`Should not be able to mint another ticket`, async function () {
        await expect(rafflable.mint()).to.be.reverted;
      });
    } else {
      it(`Should mint ticket ${i+1} of 25000`, async function () {
        await expect(rafflable.mint()).to.be.not.reverted;
      });
    }
  }
});
