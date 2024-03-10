import { HardhatUserConfig } from "hardhat/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-web3";
import "@nomicfoundation/hardhat-toolbox";
import "@primitivefi/hardhat-dodoc";
import "solidity-coverage";
import "hardhat-contract-sizer";

import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    goerli: {
      url: "https://goerli.infura.io/v3/2a15ac43eb8c4cfa94809ff08d84274d",
      accounts: {
        mnemonic: process.env.MNEMONIC,
      },
      chainId: 5,
    },
  },
  etherscan: {
    apiKey: "ZVS7QS6TGF6VNAEA267A9KP2KRCDSNRP1G",
  },
  dodoc: {
    outputDir: "./docs/contracts",
    include: [
      "contracts/governance",
      "contracts/interfaces",
      "contracts/misc",
      "contracts/reth",
      "contracts/StableAsset.sol",
      "contracts/TapETH.sol",
      "contracts/WTapETH.sol",
      "contracts/StableAssetApplication.sol",
    ],
  },
};

export default config;
