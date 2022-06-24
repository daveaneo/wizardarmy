import { useEffect, useState } from "react";
import { ethers } from "ethers";
//import WizardsNFTabi from './abi/wizards.json';
import WizardTower from './components/WizardTower';
import MyWizards from './components/MyWizards';
import "./App.css";
import "./Contracts.js";

// todo -- get components to rerender with address change
// todo -- have address change something else after, then use this to signal state change

function App() {
  const [text, setText] = useState("");
  const [savedText, setSavedText] = useState("");
  const [connected, setConnected] = useState(false);
  const [numWizards, setNumWizards] = useState(0);
//  const [signer, setSigner] = useState(window.signer);
  const [address, setAddress] = useState(undefined);
  const [counter, setCounter] = useState(1);

  const { ethereum } = window;
  const ecosystemTokenAddress = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract =window.wizardTowerContract;
  const wizardBattleContract =window.wizardBattleContract;


//  let myAddress = window.address;

  async function loadAddress() {
        let provider = new ethers.providers.Web3Provider(ethereum);
        let signer = provider.getSigner();
        signer.getAddress().then((prom) => {
          setAddress(prom);
        });
  }

  async function mintWizard() {
     wizardNFTContract.mint().then( tx => {
         tx.wait(1).then( () => {
         if(tx.status !=0 ){
           setNumWizards(numWizards + 1);
         }
         });
     });
  }

  async function updateNumWizards() {
    let num = parseInt((await wizardNFTContract.totalSupply()).toString());
    setNumWizards(num);
  }


  useEffect(() => {
  }, [numWizards]); //

  useEffect(() => {
    setCounter(counter+1);
  }, [address]); //


  useEffect(() => {
    updateNumWizards();
    if(window.address!==undefined) {
      setConnected(true);
      loadAddress();
    }
  }, []); //


  // Detect change in Metamask account
  useEffect(() => {

    if (window.ethereum) {
      window.ethereum.on("chainChanged", () => {
        console.log("chain changed.");
        let networkId = parseInt(window.ethereum.chainId);
        if (networkId !== 4) {
          console.log("WRONG NETWORK!");
        }
      });
      window.ethereum.on("accountsChanged", () => {
        console.log("account changed.");
        let signer = window.provider.getSigner();
        window.signer = signer;
        signer.getAddress().then((addr) => {
          window.address = addr;
        });
      });
    }
  });


  return (
    <div className="App">
      {address}
      <p>Wizard Army, {numWizards} strong!</p>
      <button onClick={() => {
        if (wizardNFTContract && !connected) {
            ethereum.request({ method: 'eth_requestAccounts'})
                .then(accounts => {
                    setConnected(true);
                    loadAddress();
                })
        }
        else { // disconnecting
            window.address = undefined;
            setConnected(false);
        }
      }}>{!connected ? 'Connect wallet' : 'Disconnect' }</button>

      <button onClick={() => {
        if (connected) {
            mintWizard().then(res => {
                })
        }
        else{
        }
      }}>{'mint' }</button>
      {address != undefined && <MyWizards
          connected = {connected}
          numWizards = {numWizards}
          address = {address}
       />}
      <WizardTower />
    </div>
  );
}

export default App;
