import { useEffect, useState } from "react";
import { ethers } from "ethers";
import MyWizards from '../components/MyWizards';
import "../App.css";
//import "../Contracts.js";

// todo -- get components to rerender with address change
// todo -- have address change something else after, then use this to signal state change

function Home(props) {
  const connected = props.connected;
  const address = props.address;
  const onboard = props.onboard;
//  const numWizards = props.numWizards;

  const [text, setText] = useState("");
  const [savedText, setSavedText] = useState("");
  const [numWizards, setNumWizards] = useState(0);
  const [counter, setCounter] = useState(1);
  const [contractsLoaded, setContractsLoaded] = useState(false);

  const { ethereum } = window;
  var ecosystemTokenAddress = window.ecosystemToken;
  var wizardNFTContract = window.wizardNFTContract;
  var wizardTowerContract = window.wizardTowerContract;
  var wizardBattleContract = window.wizardBattleContract;
  var loadingContracts = false;

//  const ecosystemTokenAddress = window.ecosystemToken;
//  const wizardNFTContract = window.wizardNFTContract;
//  const wizardTowerContract =window.wizardTowerContract;
//  const wizardBattleContract =window.wizardBattleContract;

  const NFTContractNoSigner = window.NFTContractNoSigner;


function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

  async function LoadContracts() {
      if(loadingContracts) { return}
      loadingContracts = true;

      while(window.ecosystemToken == undefined &&
         window.wizardNFTContract == undefined &&
         window.wizardTowerContract == undefined &&
         window.wizardBattleContract == undefined
      ) {
          await sleep(100);
      }
      var ecosystemTokenContract = window.ecosystemToken;
      var wizardNFTContract = window.wizardNFTContract;
      var wizardTowerContract =window.wizardTowerContract;
      var wizardBattleContract =window.wizardBattleContract;
      loadingContracts = false;
      setContractsLoaded(true);
  }

  async function mintWizard() {
     wizardNFTContract.mint().then( tx => {
         tx.wait(1).then( (res) => {
             if(tx.status !=0 ){
               setNumWizards(numWizards + 1);
             }
             else {
               console.log("Something went wrong with minting.")
             }
         });
     });
  }

  async function updateNumWizards() {
    if(NFTContractNoSigner!==undefined){
        let num = parseInt((await NFTContractNoSigner.totalSupply()));
        setNumWizards(num);
    }
    else{
    }
  }

  useEffect(() => {
    LoadContracts();
  }, []);

  useEffect(() => {
    updateNumWizards();

  }, [contractsLoaded, onboard]); //

  // Detect change in Metamask account


  return (
        <div className="App">
          {/*
          {connected && <button onClick={() => {
            if (connected) {
                mintWizard().then(res => {
                    })
            }
            else{
            }
          }}>{'mint' }</button>
          }
          */}
          <p className="wizardarmy-title">
            Wizard
            {"\n"} Army
           </p>
          <p className="wizardarmy-subtitle"> {numWizards} strong! </p>
            {connected && <MyWizards
                  connected = {connected}
                  numWizards = {numWizards}
                  address = {address}
               />
            }


        </div>
  );
}

export default Home;
