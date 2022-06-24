import { useEffect, useState } from "react";
import { ethers } from "ethers";


function MyWizards(props) {
  const connected = props.connected;
  const numWizards = props.numWizards;
  const address = props.address;
//  let [connected, setConnected] = useState(false);
  const [wizardIDs, setWizardIDs] = useState([]);
  const [wizards, setWizards] = useState([]);
  const [myNumWizards, setMyNumWizards] = useState(0);

  const [time, setTime] = useState(Date.now());

  // contracts
  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract =window.wizardTowerContract;
  const wizardBattleContract =window.wizardBattleContract;
  const signer = window.signer;

    async function LoadMyWizards() {
      // get balance
      console.log("(MyWizards) - my address: ", address);
      setWizardIDs([]);
      setWizards([]);
      let newWiz = [];
      if(address !== undefined) {
          let bal = await wizardNFTContract.balanceOf(address);
          setMyNumWizards(parseInt(bal));
          console.log("bal: ", parseInt(bal))
          setWizardIDs([]);
          // iterate through balance
          for(let i=0; i< bal; i++) {
//            wizardNFTContract.tokenOfOwnerByIndex(address, i).then( (id) =>{
//              console.log("I own id: ", parseInt(id));
//              setWizards([...wizards, {"id": parseInt(id), "element": "fire", "hp": 100 + parseInt(id)}]);
//              console.log("wizards: ", wizards)
//            });
                let id = await wizardNFTContract.tokenOfOwnerByIndex(address, i);
                newWiz.push({"id": parseInt(id), "element": "fire", "hp": 100 + parseInt(id)});
            }
            setWizards(newWiz);
      }
      else {
        console.log("Not connected.");
      }
    }

    useEffect(() => {
      const interval = setInterval(() => {
        LoadMyWizards();
      }, 60000);
      return () => clearInterval(interval);
    }, []);

    useEffect(() => {
      LoadMyWizards();
    }, [connected, numWizards, address]);

    useEffect(() => {
      LoadMyWizards();
    }, []);


  return (
    <div className="">
      <p className="DoubleBordered">I own {wizards.length} wizards:</p>
        {wizards && wizards.map(wizard =>
            <tr key={wizard.id} className="Double">
                <div className="DoubleBordered">
                    <td>ID: {wizard.id}</td>
                    <td>element: {wizard.element}</td>
                    <td>HP: {wizard.hp}</td>
                </div>
            </tr>
        )}
        {wizards.length != myNumWizards && 'loading...'}
        {myNumWizards == 0 && "you have no wizards."}
    </div>
  );
}

export default MyWizards;
