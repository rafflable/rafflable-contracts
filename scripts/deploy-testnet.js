// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  const TRAFF = await hre.ethers.getContractFactory("TRAFF");
  const RaffleFactory = await hre.ethers.getContractFactory("RaffleFactory");
  const RafflableFactory = await hre.ethers.getContractFactory("RafflableFactory");
  const RafflerFactory = await hre.ethers.getContractFactory("RafflerFactory");

  const traff = await TRAFF.deploy();
  console.log('TRAFF deployed at', traff.address);
  const raffle = await RaffleFactory.deploy([traff.address]);
  console.log('RaffleFactory deployed at', raffle.address);
  const rafflable = await RafflableFactory.deploy(raffle.address);
  console.log('RafflableFactory deployed at', rafflable.address);
  const raffler = await RafflerFactory.deploy(raffle.address);
  console.log('RafflerFactory deployed at', raffler.address);
  const r = await hre.ethers.getContractAt("RaffleFactory", raffle.address);
  await r.setRafflableFactory(rafflable.address);
  await r.setRafflerFactory(raffler.address);
  console.log('Updated RaffleFactory.');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
