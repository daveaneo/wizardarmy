import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { ethers } from "ethers";
import Onboard from '@web3-onboard/core'
import injectedModule from '@web3-onboard/injected-wallets'
import walletConnectModule from '@web3-onboard/walletconnect'
//import axios;


function NavBar(props) {
    const setAddress = props.setAddress;
    const address = props.address;
    const connected = props.connected;
    const setConnected = props.setConnected;
    const onboard = props.onboard;
    const setOnboard = props.setOnboard;
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
//  const [onboard, setOnboard] = useState(undefined);
//  var myonboard = undefined;

  async function setupOnboard() {
       let myonboard = await Onboard({
          wallets: [injected, walletConnect],
          chains: [
            {
              id: '0x4',
              token: 'rETH',
              label: 'Rinkeby',
              rpcUrl: myInfuraRPC
            },

// todo -- add Polygon
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

       setOnboard(myonboard)
       return myonboard;
}

  async function connectWallet() {
    // todo connection errors: connect/disconnect/connect
    var myonboard;
    if (onboard==undefined){
      myonboard = await setupOnboard();
    }
    else {
      myonboard = onboard;
    }

    const wallets = await myonboard.connectWallet()
//    const [primaryWallet] = myonboard.state.get().wallets
    if (wallets[0]) {

      // create an ethers provider with the last connected wallet provider
      const ethersProvider = new ethers.providers.Web3Provider(
        wallets[0].provider,
        'any'
      )

      const signer = ethersProvider.getSigner()
/*
      // send a transaction with the ethers provider
      const txn = await signer.sendTransaction({
        to: wallets[0],
        value: 100000000000000
      })

      const receipt = await txn.wait()
      console.log(receipt)
*/
      setConnected(true);
    }
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

// enable persist connection information between visits and refresh
  useEffect(() => {
    setConnected(JSON.parse(window.sessionStorage.getItem("connected")));
    const temp = JSON.parse(window.sessionStorage.getItem("connected"));
    loadAddress();
//    setupOnboard();
  }, []);

  useEffect(() => {
    if (connected!==undefined){
        window.sessionStorage.setItem("connected", connected);
    }
  }, [connected]);

/*
  useEffect(() => {
    console.log("onboard has changed: ", onboard)
  }, [onboard]);
*/

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
            if (!connected) {
                connectWallet();
            }
            else { // disconnecting
                window.address = undefined;
                setConnected(false);
                setAddress(undefined);
                // onboard
                if(onboard!=undefined){
                    let [primaryWallet] = onboard.state.get().wallets
                    onboard.disconnectWallet({ label: primaryWallet.label })
                }
            }
            }}>{!connected ? 'Connect wallet' : 'Disconnect' }</button>
        </div>

        <div className="navbar-item">
          {connected && <button onClick={() => {
            if (connected) {
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

//        </* <button onClick={SendTokensToTowerContract}> Power Tower </button> */>
