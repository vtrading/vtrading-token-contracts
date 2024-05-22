import * as dotenv from "dotenv";
import {HardhatUserConfig} from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.24",
        settings: {optimizer: {enabled: true, runs: 200}},
    },
    networks: {
        mainnet: {
            url: "https://mainnet.infura.io/v3/2NweCWMcWh49ay7FGooucVSLWoM",
            accounts: [process.env.PRIVATE_KEY || ''],
        },
        sepolia: {
            url: "https://sepolia.infura.io/v3/2NweCWMcWh49ay7FGooucVSLWoM",
            accounts: [process.env.PRIVATE_KEY || ''],
        },

    },
    sourcify: {
        enabled: true,
    },
    etherscan: {
        apiKey: {
            mainnet: process.env.SCAN_API_KEY || '',
            sepolia: process.env.SCAN_API_KEY || '',
        },
        customChains: [
            {
                network: "mainnet",
                chainId: 1,
                urls: {
                    apiURL: "https://api.etherscan.io/api/",
                    browserURL: "https://etherscan.io/"
                }
            },
            {
                network: "sepolia",
                chainId: 11155111,
                urls: {
                    apiURL: "https://api-sepolia.etherscan.io/api",
                    browserURL: "https://sepolia.etherscan.io"
                }
            }
        ]
    }
};

export default config;
