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
  const TokensWithExchangeRate = await ethers.getContractFactory("TokensWithExchangeRate");
  const exchangeRateToken = await TokensWithExchangeRate.attach('0x3Ea5a52a985091F37555F842A164BE66eCDF1AD1');
  console.log(`balance: ${await exchangeRateToken.balanceOf(deployer.address)}`);
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
