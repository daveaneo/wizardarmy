import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ethers } from "ethers";
import Onboard from '@web3-onboard/core'
import injectedModule from '@web3-onboard/injected-wallets'
import walletConnectModule from '@web3-onboard/walletconnect'
import { init, useConnectWallet } from '@web3-onboard/react'
//import { useSetChain } from '@web3-onboard/react'
//import axios;

  const signer = window.signer;
  const myInfuraRPC = process.env.REACT_APP_RINKEBY_RPC;
  const MAINNET_RPC_URL = process.env.REACT_APP_MAINNET_RPC;
  const injected = injectedModule()
  const walletConnect = walletConnectModule()

  // SETUP UP OnBoard
    export const onboard = init({
      wallets: [injected, walletConnect],
      chains: [
        {
          id: '0x4',
          token: 'rETH',
          label: 'Rinkeby',
          rpcUrl: myInfuraRPC
        },

    // todo -- add Polygon-
    /*            {
          id: '0x89',
          token: 'MATIC',
          label: 'Polygon',
          rpcUrl: 'https://matic-mainnet.chainstacklabs.com'
        },
    */
        {
          id: '0x13881',
          token: 'MATIC',
          label: 'Mumbai Testnet',
          rpcUrl: 'https://rpc-mumbai.maticvigil.com/'
        },
      ]
    })

