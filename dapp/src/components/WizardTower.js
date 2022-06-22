import { useEffect, useState } from "react";
import { ethers } from "ethers";
import wizardarmyabi from '../abi/wizardarmy.json';
import wizardtowerabi from '../abi/wizardtower.json';



function WizardTower() {
  let [text, setText] = useState("");
  let [savedText, setSavedText] = useState("");
  let [connected, setConnected] = useState(false);

  let { ethereum } = window;
  let contract = null;
  let Floors = [
      {"id": 1, "Element": "Fire", "Occupant": 6, "Tokens": 15212},
      {"id": 2, "Element": "Water", "Occupant": 7, "Tokens": 75732},
      {"id": 3, "Element": "Earth", "Occupant": 8, "Tokens": 783},
      {"id": 4, "Element": "Wind", "Occupant": 9, "Tokens": 3891334}
  ];
  console.log("Flooors...")
  console.log(Floors);

  if (ethereum) {
    // let wizardarmyabi = JSON.parse('[{"inputs": [{"internalType": "string","name": "newText","type": "string"}],"name": "changeText","outputs": [],"stateMutability": "nonpayable","type": "function"},{"inputs": [],"stateMutability": "nonpayable","type": "constructor"},{"inputs": [],"name": "text","outputs": [{"internalType": "string","name": "","type": "string"}],"stateMutability": "view","type": "function"}]')

    // console.log(ethereum.ethereum.networkVersion);
    let address = '0x4101fd97ee6d781bce214896d854ad79c5cffd3d';
    let provider = new ethers.providers.Web3Provider(ethereum);
    let signer = provider.getSigner();
    contract = new ethers.Contract(address, wizardarmyabi, signer);
    // const { chainId } = provider.getNetwork();
    console.log("in ethereum if statement");
    console.log(ethereum);
    console.log(provider);
    console.log(signer);
    console.log("out ethereum if statement");
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
    <div className="">
      <p className="DoubleBordered">Wizard Tower</p>
        {Floors && Floors.map(floor =>
            <tr key={floor.id} className="Double">
                <div className="DoubleBordered">
                    <td>{floor.id}</td>
                    <td>{floor.Element}</td>
                    <td>{floor.Occupant}</td>
                    <td>{floor.Tokens}</td>
                </div>
            </tr>
        )}
    </div>
  );
}

export default WizardTower;
