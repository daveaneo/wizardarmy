#!/bin/bash

# Set fixed versions
HARDHAT_VERSION="2.17.3"
ETHERS_VERSION="5.7.2"

echo "Cleaning existing packages..."

# Remove node_modules and package-lock.json for a clean slate
rm -rf node_modules
rm -f package-lock.json

# Uninstall existing packages that might conflict
npm uninstall hardhat
npm uninstall ethers
npm uninstall @nomiclabs/hardhat-ethers
npm uninstall @nomiclabs/hardhat-waffle

echo "Installing Hardhat..."
npm install --save-dev hardhat@$HARDHAT_VERSION

echo "Installing Ethers..."
npm install --save-dev ethers@$ETHERS_VERSION

echo "Installing Hardhat plugins..."
# npm install --save-dev @nomiclabs/hardhat-ethers@2.2.3  # This version should be compatible with ethers@5.7.2
npm install --save-dev @nomiclabs/hardhat-ethers 'ethers@^5.0.0'
npm install --save-dev @nomiclabs/hardhat-waffle@2.0.6  # This version is compatible with hardhat-ethers 2.2.3
npm install --save-dev hardhat-contract-sizer
npm install @nomicfoundation/hardhat-chai-matchers@1.0.6 --save-dev


echo "Installing OpenZeppelin contracts..."
npm install @openzeppelin/contracts

echo "Done!"
