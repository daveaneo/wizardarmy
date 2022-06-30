import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { BrowserRouter, Link, Route, Routes} from "react-router-dom";
//import WizardsNFTabi from './abi/wizards.json';
import WizardTower from './components/WizardTower';
import MyWizards from './components/MyWizards';
import Wizard from './components/Wizard';
import Battle from './components/Battle';
import Home from './components/Home';
import NavBar from './components/NavBar';
import ContractSettings from './components/ContractSettings';
import "./App.css";
//import "./Contracts.js";

// todo -- get components to rerender with address change
// todo -- have address change something else after, then use this to signal state change

function App() {
  const [text, setText] = useState("");
  const [savedText, setSavedText] = useState("");
  const [connected, setConnected] = useState(undefined);
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
        const newAddr = signer.getAddress();
        setAddress(newAddr);
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
    if(wizardNFTContract!==undefined){
        let num = parseInt((await wizardNFTContract.totalSupply()).toString());
        setNumWizards(num);
    }
  }


  useEffect(() => {
    updateNumWizards();
//    if(window.address!==undefined) {
//      setConnected(true);
//      loadAddress();
//    }
  }, []); //


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
        window.signer = signer;
        signer.getAddress().then((addr) => {
          window.address = addr;
        });
      });
    }
  });


  return (

    <BrowserRouter>
        <div className="App">
          <ContractSettings connected={connected} address={address} setAddress={setAddress} loadAddress={loadAddress} setConnected={setConnected}/>
          <NavBar connected={connected} address={address} setAddress={setAddress} loadAddress={loadAddress} setConnected={setConnected}/>
        <Routes>
            <Route path="/tower"
              element = {<WizardTower />}
            />
            <Route path="/wizard/:id/battle/"
                element = {<Battle connected={connected} address={address} />}
            />
            <Route path="/wizard/:id"
                element = {<Wizard connected={connected} numWizards={numWizards} address={address} />}
            />
            <Route path="/"
              element = {<Home address={address} connected={connected} numWizards={numWizards} / >}
              />
        </Routes>
        </div>
    </BrowserRouter>
  );
}

export default App;
