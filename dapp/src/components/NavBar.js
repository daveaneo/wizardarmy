import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ethers } from "ethers";
import Onboard from '@web3-onboard/core'
import {Connect, updateAccount} from '../components/Connect';
import injectedModule from '@web3-onboard/injected-wallets'
import walletConnectModule from '@web3-onboard/walletconnect'
import { init, useConnectWallet } from '@web3-onboard/react'
//import { useSetChain } from '@web3-onboard/react'
//import axios;
import { useDispatch, useSelector } from "react-redux";

function NavBar(props) {
    const setAddress = props.setAddress;
//    const address = props.address;
    const connected = props.connected;
    const setConnected = props.setConnected;
    const onboard = props.onboard;
    const numWizards = props.numWizards;
    const setNumWizards = props.setNumWizards;

  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract =window.wizardTowerContract;
  const wizardBattleContract =window.wizardBattleContract;
  const signer = window.signer;
  const myInfuraRPC = process.env.REACT_APP_RINKEBY_RPC;
  const MAINNET_RPC_URL = process.env.REACT_APP_MAINNET_RPC;
  const injected = injectedModule()
  const walletConnect = walletConnectModule()


  const dispatch = useDispatch();
  const connect = Connect();
//  const res = connect(dispatch);
  const myReduxState = useSelector((state)=> state);
  const address = useSelector(state => state.account)

  async function ConnectWallet() {
      const res = connect(dispatch);
}

  async function loadAddress() {
        let provider = new ethers.providers.Web3Provider(ethereum);
        let signer = provider.getSigner();
        let newAddr;
        try{
          newAddr = await signer.getAddress();
        } catch(e) {
       }
        setAddress(newAddr);
  }

    async function SendTokensToTowerContract() {
        ecosystemTokenContract.transfer(wizardTowerContract.address, 10**10).then( (tx) => {
            tx.wait(1).then(() => {
                console.log("Funds sent.")
            });
        });
    }

// todo -- pass this information to redux
// enable persist connection information between visits and refresh
  useEffect(() => {
//    setConnected(JSON.parse(window.sessionStorage.getItem("connected")));
//    const temp = JSON.parse(window.sessionStorage.getItem("connected"));
//    console.log("connected: ", connected)
//    loadAddress();


    const connectedAccount = window.sessionStorage.getItem("connectedAccount");
    if(connectedAccount!=""){
      const update = updateAccount(connectedAccount);
      const res = update(dispatch).then((res) =>{
//          console.log("update: ", update)
//          console.log("res: ", res);
//          console.log("reinstating connection...")
      });
//      dispatch(test);
    }

//    SetupOnboard();
  }, []);

  useEffect(() => {
//    if (connected!==undefined){
//        window.sessionStorage.setItem("connected", connected);
//    }

    if(address!=null){
        window.sessionStorage.setItem("connectedAccount", address);
    }
    else{
        window.sessionStorage.setItem("connectedAccount", "");
    }
  }, [address]);


/*
  // Detect change in Metamask account
  useEffect(() => {
    if (window.ethereum) {
      window.ethereum.on("chainChanged", () => {
        let networkId = parseInt(window.ethereum.chainId);
        if (networkId !== 4) {
          console.log("WRONG NETWORK!");
        }
      });
      window.ethereum.on("accountsChanged", () => {
        let signer = window.provider.getSigner();
//        console.log("signer A: ", signer);
        window.signer = signer;
        signer.getAddress().then((addr) => {
//          window.address = addr;
          if (address!==addr){
            setAddress(addr);
          }
        }).catch((e) => {
          console.log("no address.");
        });
      });
    }
  });
*/


  async function mintWizard() {
     let tx = await wizardNFTContract.mint();
     let res = await tx.wait(1);
     if(res ){
        setNumWizards(numWizards + 1);
     }
     else {
     }
  }

  return (
    <div className="navbar">
        <div className="navbar-item">
          <Link to="/"> Home </Link>
        </div>

        <div className="navbar-item">
            <Link to="/files/whitepaper.pdf" target="_blank" download>Whitepaper</Link>
        </div>

        <div className="navbar-item">
            <a href="https://github.com/daveaneo/wizardarmy/" target="_blank" rel="noreferrer">
              Github
            </a>
        </div>

        <div className="navbar-item">
            <a href="https://discord.gg/kRAaY6Rzbw" target="_blank" rel="noreferrer">
              Discord
            </a>
        </div>

        <div className="navbar-item">
            <button onClick={() => {
            if (myReduxState.account==undefined) {
                ConnectWallet();
            }
            else { // disconnecting

                let myRes = dispatch({
                    type: "DISCONNECT",
                  });
                // onboard
                if(onboard!=undefined){
                    let [primaryWallet] = onboard.state.get().wallets
                    onboard.disconnectWallet({ label: primaryWallet.label })
                }
            }
            }}>{myReduxState.account==undefined ? 'Connect wallet' : 'Disconnect' }</button>
        </div>

        <div className="navbar-item">
          {myReduxState.account!=undefined && <button onClick={() => {
            if (myReduxState.account!=undefined) {
                mintWizard().then(res => {
                    })
            }
            else{
            }
          }}>{'mint' }</button>
          }
        </div>

    </div>
  );
}

export default NavBar;