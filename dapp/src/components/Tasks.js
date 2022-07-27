import { useEffect, useState } from "react";
import { ethers } from "ethers";
import {Link, useParams} from "react-router-dom";
import FormData from 'form-data';
import axios from 'axios';
//import * as IPFS from "ipfs-core";
//import makeIpfsFetch from "js-ipfs-fetch";
// todo -- this page should be authenticated

function Tasks(props) {
  const connected = props.connected;
  const address = props.address;
  let params = useParams();
  const wizardId = params.id;

  const [floorIDs, setFloorIDs] = useState([]);
  const [taskTypes, setTaskTypes] = useState([]);
  const [activeFloors, setActiveFloors] = useState([]);
  const [myNumNeighboringFloors, setMyNumNeighboringFloors] = useState(0);
  const [myFloor, setMyFloor] = useState(undefined);
//  const [isInitiated, setIsInitiated] = useState(undefined);

  const [time, setTime] = useState(Date.now());
  const [contractsLoaded, setContractsLoaded] = useState(false);

  // contracts
  const { ethereum } = window;
  const ecosystemTokenContract = window.ecosystemToken;
  const wizardNFTContract = window.wizardNFTContract;
  const wizardTowerContract = window.wizardTowerContract;
  const wizardBattleContract = window.wizardBattleContract;
  const wizardGovernanceContract = window.wizardGovernanceContract;
  const signer = window.signer;
  const ELEMENTS = ["Fire", "Wind", "Water", "Earth"]
  var isInitiated = undefined;
  let isLoadingMyTasks = false;
  var loadingContracts = false;
  var myJSONFileForIPFS = {"description": "What is 5 + 9?", "fields": 1}

  const PINATA_API = process.env.REACT_APP_PINATA_API;
  const PINATA_API_SECRET = process.env.REACT_APP_PINATA_API_SECRET;
  const PINATA_JWT = process.env.REACT_APP_PINATA_JWT;

//  console.log(process.env)
//  const IPFS = require('ipfs')
//  const makeIpfsFetch = require('ipfs-fetch')

    // todo -- create new tasks for board members
//
//    async function sendFileToIPFS(myFile) {
//
//        if (Object.keys(myFile).length >= 2) {
//            try {
//                const formData = new FormData();
//                formData.append("file", myFile);
//
//                const resFile = await axios({
//                    method: "post",
//                    url: "https://api.pinata.cloud/pinning/pinFileToIPFS",
//                    data: formData,
//                    headers: {
//                        'pinata_api_key': `${process.env.REACT_APP_PINATA_API_KEY}`,
//                        'pinata_secret_api_key': `${process.env.REACT_APP_PINATA_API_SECRET}`,
//                        "Content-Type": "application/json"
//                    },
//                });
//
//                const ImgHash = `ipfs://${resFile.data.IpfsHash}`;
//             console.log(ImgHash);
////Take a look at your Pinata Pinned section, you will see a new file added to you list.
//
//
//
//            } catch (error) {
//                console.log("Error sending File to IPFS: ")
//                console.log(error)
//            }
//        }
//    }

    // todo -- overview
    // load tasks ( options to choose from)
       // load task information, allow enter information.
    // load (random) task to confirm
        // pause task on blockchain (two calls. One to pause and pay, another to submit and confirm.)
    // offer ability to create task types
    // offer ability to delete task types

    // name, description, fields
    async function loadJSONFromIPFS(cid) {
       const response = await fetch('https://blackmeta.mypinata.cloud/ipfs/bafkreifvdz4cbeur5i5og2bp3fz3fq72djjp7sabs5ebyvsuci2zei3v3i'); // todo create new ipfs account
        if(!response.ok)
          throw new Error(response.statusText);

        const json = await response.json();
//        console.log(json)
//        console.log(json.description)
        return json
}

    async function sendFileToIPFS(myFile) {
        var data = JSON.stringify({
          "pinataOptions": {
            "cidVersion": 1
          },
          "pinataMetadata": {
            "name": "MVP Task",
            "keyvalues": {
              "customkey": "key",
              "customkey2": "key2"
            }
          },
          "pinataContent": {
            "name": "MVP Task",
            "description": "what is 5 + 9?",
            "fields": 1
              }
        });

        var config = {
          method: 'post',
          url: 'https://api.pinata.cloud/pinning/pinJSONToIPFS',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + `${process.env.REACT_APP_PINATA_JWT}`
          },
          data : data
        };

        const res = await axios(config);
        console.log(res.data);
    }

//    sendFileToIPFS(myJSONFileForIPFS)
    loadJSONFromIPFS()

    // todo improve async flow
    async function processFloorStruct(floorNumber) {
        let floor = await wizardTowerContract.floorIdToInfo(floorNumber);
        let token_promise = wizardTowerContract.floorBalance(floorNumber);
        let processedFloor = {};
        processedFloor.floorNumber = parseInt(floorNumber);
        processedFloor.lastWithdrawalTimestamp = parseInt(floor.lastWithdrawalTimestamp);
        processedFloor.occupyingWizardId = parseInt(floor.occupyingWizardId);
        processedFloor.element = ELEMENTS[parseInt(floor.element)];

//        token_promise = wizardTowerContract.floorBalance(floorNumber);
        let tokens = parseInt(await token_promise);
        processedFloor.tokens = tokens;
        return processedFloor;
    }

    async function CompleteTask(_id) {
        console.log("Task will be completed: ", _id);
    }

    async function LoadMyTasks() {
      if(isLoadingMyTasks == true){
          return;
      }
      else {
        isLoadingMyTasks = true;
      }

      if(wizardGovernanceContract===undefined || wizardNFTContract === undefined){
        console.log("GovernanceContract or NFT is not defined.")
        return;
      }
      else if(isInitiated===undefined){
        isInitiated = await wizardNFTContract.getStatsGivenId(wizardId);
        isInitiated = parseInt(isInitiated.initiationTimestamp) !== 0;
      }

      let newTaskTypes = [];
      let taskObjects = []
      let taskObject = undefined;
      if(connected && (address !== undefined)) {
          taskObject = {}
          newTaskTypes = await wizardGovernanceContract.getMyAvailableTaskTypes();
          for(let i = 0; i< newTaskTypes.length; i++){
            taskObject.id = i;
            taskObject.IPFS = newTaskTypes;
            taskObjects.push(taskObject);
          }

//          newTaskTypes.sort((a, b) => (a.floorNumber - b.floorNumber));
//          setTaskTypes(newTaskTypes);
          taskObjects.sort((a, b) => (a.id - b.id));
          setTaskTypes(taskObjects);
      }

      else {
        console.log("Not connected.");
      }
        isLoadingMyTasks = false;
    }


function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

  async function CreateTaskType() {
    console.log("to do");
  }

  async function DeleteTaskType() {
    console.log("to do");
  }


  async function ConfirmCompletedTask() {
    console.log("to do");
    // transact with blockchain, claiming one task (15 minute limit)
    // populate information in order to confirm
    // submit
  }

  async function LoadContracts() {
      if(loadingContracts) { return}
      loadingContracts = true;

      while(window.ecosystemToken == undefined &&
         window.wizardNFTContract == undefined &&
         window.wizardTowerContract == undefined &&
         window.wizardBattleContract == undefined &&
         window.wizardGovernanceContract == undefined
      ) {
          await sleep(100);
      }
      var ecosystemTokenContract = window.ecosystemToken;
      var wizardNFTContract = window.wizardNFTContract;
      var wizardTowerContract = window.wizardTowerContract;
      var wizardBattleContract = window.wizardBattleContract;
      var wizardGovernanceContract = window.wizardGovernanceContract;
      loadingContracts = false;
      setContractsLoaded(true);
  }


    useEffect(() => {
      LoadContracts();
      const interval = setInterval(() => {
        if(contractsLoaded===true){
            LoadMyTasks();
        }
      }, 60000);
      return () => clearInterval(interval);
    }, []);


    useEffect(() => {
        LoadMyTasks();
    }, [connected, address]);

    useEffect(() => {
      LoadContracts();
    }, []);

    useEffect(() => {
      if(contractsLoaded===true){
         LoadMyTasks();
      }
    }, [contractsLoaded]);

  return (
    <div className="">
      <p className="DoubleBordered">Available tasks</p>
        {taskTypes && taskTypes.map(taskType =>
            <div key={taskType.id} className="Double">
                <br/>

                Task {taskType.id}
                <br/>
                <div className="DoubleBordered">
                    <div>IPFS Link: {taskType.IPFS}</div>
                    <div>Assignment: {taskType.IPFS}</div>
                    <div>
                       <button onClick={() => CompleteTask(taskType.ID)}> Complete </button>
                    </div>
                </div>
            </div>
        )}
        <div>
           <button onClick={() => ConfirmCompletedTask()}> Confirm Completed Task </button>
        </div>
        <div>
           <button onClick={() => CreateTaskType()}> Create Task Type </button>
        </div>
        <div>
           <button onClick={() => DeleteTaskType()}> Delete Task Type </button>
        </div>
        {!connected && "Please Connect"}
        {connected && (taskTypes == undefined) && 'loading...'}
    </div>
  );
}

export default Tasks;
