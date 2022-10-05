import { useEffect, useState } from "react";
import { ethers } from "ethers";
//import wizardarmyabi from '../abi/wizardarmy.json';
//import wizardtowerabi from '../abi/wizardtower.json';
import { Link } from 'react-router-dom';
import { useSelector } from "react-redux";


function WizardTower() {
//  let [connected, setConnected] = useState(false);
  let [floors, setFloors] = useState([]);
  let [numFloors, setNumFloors] = useState(0);
//  let [stateCounter, setStateCounter] = useState(0);
  let [towerBalance, setTowerBalance] = useState(0);

  const [time, setTime] = useState(Date.now());

  // contracts
  const smartContracts = useSelector(state => state.smartContracts)
  const address = useSelector(state => state.account)

  // Load signed, unsigned contracts from Redux
//  const NFTContractNoSigner = smartContracts.nftContractNoSigner;
  const ecosystemTokenContract = smartContracts.ecosystemTokenContract;
//  const wizardNFTContract = smartContracts.wizardNFTContract;
  const wizardTowerContract =smartContracts.wizardTowerContract;
//  const wizardBattleContract =smartContracts.wizardBattleContract;

    async function LoadNumTowerFloors() {
      wizardTowerContract.activeFloors().then((activeFloors) => {
        setNumFloors(parseInt(activeFloors));
      });
    }

    async function LoadTowerBalance() {
      ecosystemTokenContract.balanceOf(wizardTowerContract.address).then( (bal) => {
          setTowerBalance(parseInt(bal));
      });

    }


    async function LoadFloors() {

        for(let i=1;i <= numFloors; i++){
          wizardTowerContract.floorIdToInfo(i).then( (floorInfo) => {
          });
        }
    }



    useEffect(() => {
      const interval = setInterval(() => {
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
