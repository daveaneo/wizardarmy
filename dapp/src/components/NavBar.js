import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ethers } from "ethers";
//import axios;

function NavBar(props) {
    const setAddress = props.setAddress;
    const address = props.address;
    const connected = props.connected;
    const setConnected = props.setConnected;

  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract =window.wizardTowerContract;
  const wizardBattleContract =window.wizardBattleContract;
  const signer = window.signer;


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

// enable persist connection information between visits and refresh
  useEffect(() => {
    setConnected(JSON.parse(window.sessionStorage.getItem("connected")));
    const temp = JSON.parse(window.sessionStorage.getItem("connected"));
    loadAddress();
  }, []);

  useEffect(() => {
    if (connected!==undefined){
        window.sessionStorage.setItem("connected", connected);
    }
  }, [connected]);

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

  return (
    <div className="NavBar">
      <div>
        <Link to="/"> Home </Link>

        <Link to="/files/whitepaper.pdf" target="_blank" download>Whitepaper</Link>
        <a href="https://github.com/daveaneo/wizardarmy/" target="_blank" rel="noreferrer">
          Github
        </a>
        <a href="https://discord.gg/kRAaY6Rzbw" target="_blank" rel="noreferrer">
          Discord
        </a>
        <button onClick={() => {
        if (wizardNFTContract && !connected) {
            ethereum.request({ method: 'eth_requestAccounts'})
                .then(accounts => {
                    setConnected(true);
        //                    loadAddress();
                })
        }
        else { // disconnecting
            window.address = undefined;
            setConnected(false);
            setAddress(undefined);
        }
        }}>{!connected ? 'Connect wallet' : 'Disconnect' }</button>
        <button onClick={SendTokensToTowerContract}> Power Tower </button>
        </div>


    </div>
  );
}

export default NavBar;
