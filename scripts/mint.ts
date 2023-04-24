import { ethers, upgrades } from "hardhat";

const PRECISION = '1';
const MINT_FEE = '10000000';
const SWAP_FEE = '20000000';
const REDEEM_FEE = '50000000';
const FEE_DENOMITOR = '10000000000';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(deployer.address);
  const StableSwap = await ethers.getContractFactory("StableSwap");
  const MockToken = await ethers.getContractFactory("MockToken");
  const TokensWithExchangeRate = await ethers.getContractFactory("TokensWithExchangeRate");
  const cbETH = await MockToken.attach('0xd994DD0FA5D62306BC2E46B96104E7Fda80Afa62');
  await cbETH.mint(deployer.address, '100000000000000000000');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
