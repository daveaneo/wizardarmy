import { useEffect, useState } from "react";
import { ethers } from "ethers";
import abi from './abi/wizardarmy.json';

function App() {
  let [text, setText] = useState("");
  let [savedText, setSavedText] = useState("");
  let [connected, setConnected] = useState(false);

  let { ethereum } = window;
  let contract = null;

  if (ethereum) {
    // let abi = JSON.parse('[{"inputs": [{"internalType": "string","name": "newText","type": "string"}],"name": "changeText","outputs": [],"stateMutability": "nonpayable","type": "function"},{"inputs": [],"stateMutability": "nonpayable","type": "constructor"},{"inputs": [],"name": "text","outputs": [{"internalType": "string","name": "","type": "string"}],"stateMutability": "view","type": "function"}]')

    // console.log(ethereum.ethereum.networkVersion);
    let address = '0x4101fd97ee6d781bce214896d854ad79c5cffd3d';
    let provider = new ethers.providers.Web3Provider(ethereum);
    let signer = provider.getSigner();
    contract = new ethers.Contract(address, abi, signer);
    // const { chainId } = provider.getNetwork();    
    console.log("in ethereum if statement");
    console.log(ethereum);
    console.log(provider);
    console.log(signer);
    console.log("out ethereum if statement");
  }

  async function asyncCall() {
    // expected output: "resolved"
  }

  // testing
  useEffect(() => {
  }, [text]); //

  // Detect change in Metamask account
  useEffect(() => {
    if (window.ethereum) {
      console.log('in use Effect');
      window.ethereum.on("chainChanged", () => {
        console.log("chain changed.");
        let networkId = parseInt(window.ethereum.chainId);
        if (networkId !== 4) {
          console.log("WRONG NETWORK!");
        }
      });
      window.ethereum.on("accountsChanged", () => {
        console.log("account changed.")
      });
    }
  });


  return (
    <div className="App">
      <p>Wizard Army</p>
      <button onClick={() => {
        if (contract && !connected) {
            ethereum.request({ method: 'eth_requestAccounts'})
                .then(accounts => {
                    setConnected(true);
                })
        }
      }}>{!connected ? 'Connect wallet' : 'Connected' }</button>


      <form onSubmit={(e) => {
        e.preventDefault();
        console.log("hello");
        if (contract && connected) {
          contract.setmyString(text)
            .then(() => {
              setText("");
            });
        }
      }}>
          <input type="text" placeholder="Enter text" onChange={e => setText(e.currentTarget.value)} value={text} />
          <input type="submit" value="save to contract" />
      </form>

      <button onClick={() => {
        if (contract && connected) {
          contract.myString()
            .then(text => {
              setSavedText(text);
            })
        }
      }}>Get Text</button>

      <span>{savedText}</span>
    </div>
  );
}

export default App;
