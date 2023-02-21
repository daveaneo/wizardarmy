import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { useSelector, useDispatch } from "react-redux";
//const dotenv = require('dotenv');
import {onboard} from '../components/Onboard';
import injectedModule from '@web3-onboard/injected-wallets';
import walletConnectModule from '@web3-onboard/walletconnect';
import { init, useConnectWallet } from '@web3-onboard/react';

const WizardsNFTabi = require('../abi/wizards.json').abi;
const WizardTowerabi = require('../abi/wizardtower.json').abi;
const WizardBattleabi = require('../abi/wizardbattle.json').abi;
const WizardGovernanceabi = require('../abi/wizardgovernance.json').abi;
const ERC20abi = require('../abi/ERC20.json').abi;
const myInfuraMumbaiRPC = process.env.REACT_APP_MUMBAI_RPC;
const myInfuraRinkebyRPC = process.env.REACT_APP_RINKEBY_RPC;
const networkIdUsed = process.env.REACT_APP_CORRECT_CHAIN_ID;
const injected = injectedModule()
const walletConnect = walletConnectModule()

let ecosystemTokenAddress = '0x81EB27e67164ae098886d2A7F1AdF4704A48B1D9';
let wizardNFTAddress = '0xeF2249fdb81daacf6028236CBA3c583F15F2Eb65';
let wizardTowerAddress = '0xF14B1a8Cf48295d49708969547782C827bb374eE';
let wizardBattleAddress = '0x4Fd82bb0736D2364b7B944c2aFd4Ed47F5B36123';
let wizardGovernanceAddress = '0x47637ea1c7620A6eCAF87A2d79be8DE786e51698';
let wizardAppointerAddress = '0x6D4A45B9D874692aa62984fa679CcFC26053AfB3';


 // load some data without metamask or signer
function getNFTContractNoSigner() {
  const chainId = networkIdUsed;
  let myRPC;
  console.log("chainid: ", chainId)
  if(chainId==4){
    myRPC= myInfuraRinkebyRPC;
  }
  else if(chainId==80001 ){
    myRPC= myInfuraMumbaiRPC;
  }
  else{
    return undefined; // errors???
  }

  const provider = new ethers.providers.JsonRpcProvider(myRPC);
  var nftContract = ( new ethers.Contract(wizardNFTAddress, WizardsNFTabi, provider));
  return nftContract;
}

 export const nftContractNoSigner = getNFTContractNoSigner();


  // create contracts that don't need signatures

// remove since we are using redux;
/*
  if(window.NFTContractNoSigner===undefined){
      const noSigninNFTContract = getNFTContractNoSigner().then( (contract) => {
        window.NFTContractNoSigner = contract;
      });
   }
*/


    const connectRequest = () => {
      return {
        type: "CONNECTION_REQUEST",
      };
    };

    const connectSuccess = (payload) => {
      return {
        type: "CONNECTION_SUCCESS",
        payload: payload,
      };
    };

    const connectFailed = (payload) => {
      return {
        type: "CONNECTION_FAILED",
        payload: payload,
      };
    };

    const updateAccountRequest = (payload) => {
      return {
        type: "UPDATE_ACCOUNT",
        payload: payload,
      };
    };

    // todo -- load unsigned contracts with redux

    export const Connect = () => {
      return async (dispatch) => {
        dispatch(connectRequest());

        if (onboard==undefined){
            dispatch(connectFailed("onboard undefined."));
            return;
        }

        // ask user to connect wallet
        const wallets = await onboard.connectWallet()
    //    const [primaryWallet] = onboard.state.get().wallets
        if (wallets[0]) {
          const provider = new ethers.providers.Web3Provider(
            wallets[0].provider,
            'any'
          )
          const signer = provider.getSigner()
          const payload = getContractPayloadFromAccount(wallets[0].accounts[0].address)

          try {
            const accounts = await window.ethereum.request({
              method: "eth_requestAccounts",
            });
            const networkId = await window.ethereum.request({
              method: "net_version",
            });

            dispatch(connectSuccess(payload));
              // Add listeners start
              window.ethereum.on("accountsChanged", (accounts) => {
                const payload = getContractPayloadFromAccount(accounts[0]);
                dispatch(updateAccountRequest(payload));
              });
              window.ethereum.on("chainChanged", () => {
                window.location.reload();
              });
              // Add listeners end

// Wrong network handled elsewhere
//            } else {
//              dispatch(connectFailed("Change network to Polygon."));
//            }

          } catch (err) {
            dispatch(connectFailed("Something went wrong."));
          }
        }
      };
    };

/*
    export const updateAccount = (account) => {
      return async (dispatch) => {
          dispatch(updateAccountRequest({ account: account }));
//        dispatch(fetchData(account));
      };
    };
*/
    export const updateAccount = (account) => {
      return async (dispatch) => {
        const payload = getContractPayloadFromAccount(account);
        dispatch(updateAccountRequest(payload));
     }
    }

    function getContractPayloadFromAccount (account) {
        if (account) {
            let ethersProvider = new ethers.providers.Web3Provider(window.ethereum);
            let signer = ethersProvider.getSigner();

            // create contracts
            const ecosystemTokenContract = new ethers.Contract(ecosystemTokenAddress, ERC20abi, signer);
            const wizardNFTContract = new ethers.Contract(wizardNFTAddress, WizardsNFTabi, signer);
            const wizardTowerContract = new ethers.Contract(wizardTowerAddress, WizardTowerabi, signer);
            const wizardBattleContract = new ethers.Contract(wizardBattleAddress, WizardBattleabi, signer);
            const wizardGovernanceContract = new ethers.Contract(wizardGovernanceAddress, WizardGovernanceabi, signer);

            const checksummedAccount = ethers.utils.getAddress(account);

            return {
                  account: checksummedAccount,
                  smartContracts: {
                      ecosystemTokenContract: ecosystemTokenContract,
                      wizardNFTContract:wizardNFTContract,
                      wizardTowerContract: wizardTowerContract,
                      wizardBattleContract: wizardBattleContract,
                      wizardGovernanceContract: wizardGovernanceContract
                  },
            }
        }
        else{
        return;
        }
}
