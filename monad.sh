#!/bin/bash

# Function to display GitHub logo
show_logo() {
    echo "Downloading and displaying logo..."
    curl -s https://raw.githubusercontent.com/0xtnpxsgt/logo/refs/heads/main/logo.sh | bash
}

# Function to get and display the contract address from the deployment output
get_contract_address() {
    local output_file="deployment_output.txt"
    local contract_address
    
    contract_address=$(grep -o '0x[a-fA-F0-9]\{40\}' "$output_file")
    
    if [ -n "$contract_address" ]; then
        echo "Contract Address: $contract_address"
        echo "Contract Link: https://testnet.monadexplorer.com/address/$contract_address"
        echo "✅ Contract deployed successfully!"
    else
        echo "❌ Couldn't find contract address in deployment output"
    fi
}

# Function to deploy the KOPIHITAM contract
deploy_sc() {
    mkdir -p monad
    cd monad || exit
    npm init -y
    
    echo "Installing project dependencies..."
    npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox-viem typescript ts-node @nomicfoundation/hardhat-ignition
    
    cat > hardhat.config.ts << 'EOL'
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import { vars } from "hardhat/config";

const config: HardhatUserConfig = {
  solidity: "0.8.27",
  networks: {
    monadTestnet: {
      url: "https://testnet-rpc.monad.xyz/",
      accounts: [vars.get("PRIVATE_KEY")],
      chainId: 10143,
      timeout: 180000,
      gas: 2000000,
      gasPrice: 60806040,
      httpHeaders: {
        "Content-Type": "application/json",
      }
    }
  }
};

export default config;
EOL

    mkdir -p contracts
    cat > contracts/KOPIHITAM.sol << 'EOL'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KOPIHITAM is ERC20, Ownable {
    constructor() ERC20("KOPIHITAM", "KOP") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }
}
EOL

    mkdir -p ignition/modules
    cat > ignition/modules/KOPIHITAM.ts << 'EOL'
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const KOPIHITAMModule = buildModule("KOPIHITAMModule", (m) => {
    const kopihitam = m.contract("KOPIHITAM");
    return { kopihitam };
});

export default KOPIHITAMModule;
EOL

    echo "Enter PRIVATE_KEY (without 0x):"
    read -r private_key
    npx hardhat vars set PRIVATE_KEY "$private_key"
    
    echo "Compiling contract..."
    npx hardhat compile
    
    echo "Starting contract deployment..."
    deploy_with_retry
    echo "Setup and deployment completed!"
}

deploy_with_retry() {
    local max_retries=3
    local wait_time=10
    local attempt=1
    local output_file="deployment_output.txt"
    
    while [ $attempt -le $max_retries ]; do
        echo "Attempt deployment ke-$attempt of $max_retries..."
        
        if npx hardhat ignition deploy ./ignition/modules/KOPIHITAM.ts --network monadTestnet | tee "$output_file"; then
            echo "Deployment successful!"
            get_contract_address
            return 0
        else
            if [ $attempt -lt $max_retries ]; then
                echo "Deployment failed, waiting $wait_time seconds before retrying..."
                sleep $wait_time
                wait_time=$((wait_time * 2))
            fi
        fi
        attempt=$((attempt + 1))
    done
    
    echo "Deployment failed after $max_retries attempts"
    return 1
}

clear
show_logo
echo "================================="
echo "   KOPIHITAM Token Deployment   "
echo "================================="
echo "1. Deploy Smart Contract"
echo "2. Exit"
echo "================================="
echo "Choose option (1-2):"
read -r choice

case $choice in
    1)
        deploy_sc
        ;;
    2)
        echo "Exiting program..."
        exit 0
        ;;
    *)
        echo "Invalid choice!"
        ;;
esac
