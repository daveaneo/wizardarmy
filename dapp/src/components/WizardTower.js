import { useEffect, useState } from "react";
import { ethers } from "ethers";
//import wizardarmyabi from '../abi/wizardarmy.json';
//import wizardtowerabi from '../abi/wizardtower.json';



function WizardTower() {
  let [connected, setConnected] = useState(false);
  let [floors, setFloors] = useState([]);
  let [numFloors, setNumFloors] = useState(0);
  let [stateCounter, setStateCounter] = useState(0);
  let [towerBalance, setTowerBalance] = useState(0);

  const [time, setTime] = useState(Date.now());

  // contracts
  let { ethereum } = window;
  let ecosystemTokenContract = window.ecosystemToken;
  let wizardNFTContract = window.wizardNFTContract;
  let wizardTowerContract =window.wizardTowerContract;
  let wizardBattleContract =window.wizardBattleContract;

    async function LoadNumTowerFloors() {
      wizardTowerContract.activeFloors().then((activeFloors) => {
//        console.log("active Floors %i", parseInt(activeFloors));
        setNumFloors(parseInt(activeFloors));
//        console.log("numFloors: %i", numFloors);
      });
//      let newFloors = numFloors;
//      numFloors +=1;
//      newFloors.push({"id": numFloors, "Element": "Wind", "Occupant": 9, "Tokens": 3891334});
//      setFloors(newFloors);
//      setStateCounter(numFloors);
    }

    async function LoadTowerBalance() {
//      let tempBalance = await ecosystemTokenContract.balanceOf(wizardTowerContract.address);
//      console.log("Tower Balance: ", tempBalance);
//      setTowerBalance(tempBalance);
      ecosystemTokenContract.balanceOf(wizardTowerContract.address).then( (bal) => {
//          console.log("Tower Balance: ", parseInt(bal));
          setTowerBalance(parseInt(bal));
      });

    }


    async function LoadFloors() {

        for(let i=1;i <= numFloors; i++){
//          console.log("in for loop ABC");
          wizardTowerContract.floorIdToInfo(i).then( (floorInfo) => {
//            console.log('floor %i: %o,', i, floorInfo );
          });
        }
    }
  // Detect change in Metamask account
/*
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
        console.log("account changed.")
      });
    }
  });
*/

    // update every second
//    useEffect(() => {
//      const interval = setInterval(() => setTime(Date.now()), 1000);
//      return () => {
//        clearInterval(interval);
//      };
//    }, []);


    useEffect(() => {
      const interval = setInterval(() => {
//        console.log('Refreshing numFloors');
        LoadNumTowerFloors();
        LoadTowerBalance();
      }, 60000);
      return () => clearInterval(interval);
    }, []);

    useEffect(() => {
      LoadNumTowerFloors();
      LoadTowerBalance();
    }, []);

    useEffect(() => {
         LoadFloors();
    }, [numFloors]);


  return (
    <div className="">
      <p className="DoubleBordered">Wizard Tower has {numFloors} floors and {towerBalance} tokens.</p>
        {floors && floors.map(floor =>
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
