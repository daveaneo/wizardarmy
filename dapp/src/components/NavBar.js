import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ethers } from "ethers";
import Onboard from '@web3-onboard/core'
import {Connect, updateAccount} from '../components/Connect';
import { init, useConnectWallet } from '@web3-onboard/react'
import { useDispatch, useSelector } from "react-redux";

function NavBar(props) {
    const setAddress = props.setAddress;
//    const connected = props.connected;
//    const setConnected = props.setConnected;
    const onboard = props.onboard;
    const numWizards = props.numWizards;
    const setNumWizards = props.setNumWizards;

  const smartContracts = useSelector(state => state.smartContracts)
  const address = useSelector(state => state.account)

  // Load signed, unsigned contracts from Redux
//  const NFTContractNoSigner = smartContracts.nftContractNoSigner;
  const ecosystemTokenContract = smartContracts.ecosystemTokenContract;
  const wizardNFTContract = smartContracts.wizardNFTContract;
//  const wizardTowerContract =smartContracts.wizardTowerContract;
//  const wizardBattleContract =smartContracts.wizardBattleContract;

  const signer = window.signer;


  const dispatch = useDispatch();
  const connect = Connect();
  const myReduxState = useSelector((state)=> state);

  async function ConnectWallet() {
      const res = connect(dispatch);
}

//  async function loadAddress() {
//        let provider = new ethers.providers.Web3Provider(window.ethereum);
//        let signer = provider.getSigner();
//        let newAddr;
//        try{
//          newAddr = await signer.getAddress();
//        } catch(e) {
//       }
//        setAddress(newAddr);
//  }

// enable persist connection information between visits and refresh
  useEffect(() => {
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
  }, []);

  useEffect(() => {
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
     let tx = await wizardNFTContract.mint(0);
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
            <button className="nonStyledButton" onClick={() => {
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
            }}>{myReduxState.account==undefined ? 'Connect' : 'Disconnect' }</button>
        </div>

        <div className="navbar-item">
          {myReduxState.account!=undefined && <button className="nonStyledButton" onClick={() => {
            if (myReduxState.account!=undefined) {
                mintWizard().then(res => {
                    })
            }
            else{
            }
          }}>{'Mint' }</button>
          }
        </div>

    </div>
  );
}

export default NavBar;