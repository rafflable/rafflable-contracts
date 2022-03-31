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

  const raffleName = 'The Testnet Ticket';
  const raffleSymbol = 'TTT';
  const raffleCreator = '0x4C264608F436abAD2A51D13B9836F5f2d02b3E7c';
  const raffleURI = 'https://static.rafflable.io/tickets/the-testnet-ticket/';
  const raffleSecretURI = '';
  const raffleConfigURI = 'https://static.rafflable.io/tickets/the-testnet-ticket/config.json';
  const raffleAmountTicket = 10000;
  const raffleTimelock = 0; // not timelocked

  const TRAFF = await hre.ethers.getContractFactory("TRAFF");
  const KRC721Rafflable = await hre.ethers.getContractFactory("KRC721Rafflable");
  const Raffler = await hre.ethers.getContractFactory("Raffler");

  let krc721 = await KRC721Rafflable.deploy(
    raffleName, raffleSymbol, raffleConfigURI, raffleURI,
    raffleSecretURI, raffleAmountTicket, raffleTimelock, raffleCreator
  );
  krc721 = await ethers.getContractAt("KRC721Rafflable", krc721.address);
  console.log("KRC721Rafflable -> ", krc721.address);
  let traff = await TRAFF.deploy();
  await traff.deployed();
  await krc721.addTokenCost(traff.address, '50000000'); // 50 RUSD-T
  console.log("  addTokenCost():", traff.address,":", '50000000');

  let raffler = await Raffler.deploy(krc721.address);
  await raffler.deployed();
  console.log("Raffler -> ", raffler.address);
  await raffler.addTokenPrize(traff.address, '5000000000'); // 5000 RUSD-T
  console.log("  addTokenAndPrize():", traff.address,":", '5000000000');
  await krc721.setRaffler(raffler.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
