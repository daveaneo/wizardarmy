import { useEffect, useState } from "react";
import { ethers, utils } from "ethers";
import {Link, useParams} from "react-router-dom";
import FormData from 'form-data';
import axios from 'axios';
//import * as IPFS from "ipfs-core";
//import makeIpfsFetch from "js-ipfs-fetch";
// todo -- this page should be authenticated
import { useSelector } from "react-redux";

function Tasks(props) {
//  const connected = props.connected;
//  const address = props.address;
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
  const [newTaskDescription, setNewTaskDescription] = useState("");
  const [newProposalDescription, setNewProposalDescription] = useState("");
  const [numFieldsForProposal, setNumFieldsForProposal] = useState(1);
  const [numFieldsForTask, setNumFieldsForTask] = useState(1);
  const [maxSlotsForTask, setMaxSlotsForTask] = useState(2**16-1);
  const [myInputs, setMyInputs] = useState([]);
  const [activeTask, setActivedTask] = useState(0);
  const [taskToConfirm, setTaskToConfirm] = useState({});
  const [areTasksAvailableToConfirm, setAreTasksAvailableToConfirm] = useState(false);
  const [IPFSCidToDelete, setIPFSCidToDelete] = useState(undefined);
  const [onBoard, setOnBoard] = useState(undefined);

  // contracts
  const smartContracts = useSelector(state => state.smartContracts)
  const address = useSelector(state => state.account)

  // Load signed, unsigned contracts from Redux
//  const NFTContractNoSigner = smartContracts.nftContractNoSigner;
  const ecosystemTokenContract = smartContracts.ecosystemTokenContract;
  const wizardNFTContract = smartContracts.wizardNFTContract;
  const wizardTowerContract =smartContracts.wizardTowerContract;
  const wizardBattleContract =smartContracts.wizardBattleContract;
  const wizardGovernanceContract =smartContracts.wizardGovernanceContract;



  const ELEMENTS = ["Fire", "Wind", "Water", "Earth"]
  var isInitiated = undefined;
  let isLoadingMyTasks = false;
  var loadingContracts = false;

  const PINATA_API = process.env.REACT_APP_PINATA_API;
  const PINATA_API_SECRET = process.env.REACT_APP_PINATA_API_SECRET;
  const PINATA_JWT = process.env.REACT_APP_PINATA_JWT;


    async function fetchWithTimeout(resource, options = {}) {
      const { timeout = 6000 } = options;

      const controller = new AbortController();
      const id = setTimeout(() => controller.abort(), timeout);
      const response = await fetch(resource, {
        ...options,
        signal: controller.signal
      });
      clearTimeout(id);
      return response;
    }

    // name, description, fields
    async function loadJSONFromIPFS(cid) {
       let link = 'https://ipfs.io/ipfs/' + cid;
       var response = {"ok": false};
       try{
           response = await fetchWithTimeout(link);
       }
       catch (error){
           console.log("fetching timeout for cid: ", cid);
       }
//       const response = await fetch(link);
        if(!response.ok){
            //          throw new Error(response.statusText);
            return null;
        }

        const json = await response.json();
        return json
}

    async function sendFileToIPFS(data) {
//        setTimeout(function () {
//            console.log('Function took too long');
//        }, 2000); // after 5s


        var config = {
          method: 'post',
          url: 'https://api.pinata.cloud/pinning/pinJSONToIPFS',
          timeout: 2000, // only wait for 10s
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + `${process.env.REACT_APP_PINATA_JWT}`
          },
          data : data
        };

        // todo -- make timeout function
        let res = await axios(config);
//        myTimeout = await setTimeout();
        if(res.status!=200){
          throw new Error(res.statusText);
        }
        return res.data;
    }

//    sendFileToIPFS(myJSONFileForIPFS)
//    loadJSONFromIPFS()


    async function handleUserInputChange(data, inputId) {
        let tempInputArray = myInputs;
        tempInputArray[inputId] = data;
        setMyInputs([...tempInputArray]);
    }

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

/*
    // Working for retuted and not refuted
    async function TestHash() {
        let refuted = false;
        let leaves = ["hello", "motto"]
        let unhashedLeaves = []
        let hashedLeaves = []
        let onceHashedLeaves = []
        let twiceHashedLeaves = []
        let hashTypes = []
        // hash all leafs
        for(let i =0; i < leaves.length; i++){
            let temp = utils.keccak256(utils.toUtf8Bytes(leaves[i]))
            onceHashedLeaves.push(utils.keccak256(utils.toUtf8Bytes(leaves[i])));
            temp = utils.keccak256(temp);
            twiceHashedLeaves.push(temp);
            hashTypes.push("bytes");
        }

        let finalHash;
        let tx = undefined;
        if(refuted){
            finalHash = ethers.utils.solidityKeccak256(hashTypes, twiceHashedLeaves)
        }
        else{
            finalHash = ethers.utils.solidityKeccak256(hashTypes, onceHashedLeaves)
        }

        tx = await wizardGovernanceContract.testHashing(finalHash, onceHashedLeaves, refuted)
        let res = await tx.wait(1)
        console.log('res.events.args: ', res.events[0].args)
    }
*/

    async function updatePendingTasksToConfirm() {
//       console.log("wizID: ", wizardId);
       let myReturn = await wizardGovernanceContract.getTasksAssignedToWiz(wizardId);
       let tasks = myReturn[0];
       let myTaskIds = myReturn[1];

//       console.log("TASKS: ", tasks, myTaskIds);
       if(tasks[0].IPFSHash=="" || tasks[0].IPFSHash==undefined){
         if(taskToConfirm.IpfsHash!=undefined){
           setTaskToConfirm({});
         }
       }
       else{
           console.log("getting task stuff.")
           let myObj ={"taskId": parseInt(myTaskIds[0]), "IPFSHash": tasks[0]["IPFSHash"], "numFields": tasks[0]["numFieldsToHash"], "refuted": parseInt(tasks[0].refuterID)!=0}
           let myTask = await LoadTextFieldOntoConfirmingTask(myObj);
           setTaskToConfirm({...myTask});
       }
   }

    async function updateAreTasksAvailableToConfirm() {
        if(wizardGovernanceContract==undefined){ return;}
        let available = await wizardGovernanceContract.areTasksAvailableToConfirm(wizardId);
        setAreTasksAvailableToConfirm(available);
    }

    async function CompleteTask(_id) {
        let hashedLeaves = []
        let hashTypes = []
        // hash all leafs
        for(let i =0; i < myInputs.length; i++){
            hashedLeaves.push(utils.keccak256(utils.toUtf8Bytes(myInputs[i])));
            hashTypes.push("bytes");
        }

        let finalHash = ethers.utils.solidityKeccak256(hashTypes, hashedLeaves)
        let tx = await wizardGovernanceContract.completeTask(taskTypes[_id].IPFS, finalHash, wizardId);
        let res = await tx.wait(1);
        if(res){
          // update tasks
            console.log("events: ", res.events[0])
            console.log("Task complete. Loading new tasks.")
            console.log("id: ", _id)
            let remTasks = taskTypes.filter(function(tt) {
                return tt.id !== _id
            });
            console.log("remTasks: ", remTasks)
            setTaskTypes(remTasks);
            LoadMyTasks();
        }
        else{
            console.log("task complete but res not passing...")
        }
    }


    async function LoadMyTasks() {
      if(isLoadingMyTasks == true){
          return;
      }
      else {
        isLoadingMyTasks = true;
      }

      if(wizardGovernanceContract===undefined || wizardNFTContract === undefined){
//        console.error("GovernanceContract or NFT is not defined.")
        return;
      }
      else if(isInitiated===undefined){
        isInitiated = await wizardNFTContract.getStatsGivenId(wizardId);
        isInitiated = parseInt(isInitiated.initiationTimestamp) !== 0;
      }

      let newTaskTypes = [];
      let taskObjects = []
      if(address!=null && (address !== undefined)) {
          newTaskTypes = await wizardGovernanceContract.getMyAvailableTaskTypes(wizardId); // will need task ID too
          if(newTaskTypes[0]==""){
            return;
          }
          for(let i = 0; i< newTaskTypes.length; i++){
            let taskObject = {};
            taskObject = await loadJSONFromIPFS(newTaskTypes[i]);
            if(taskObject==null){
//              console.log('error loading task from IPFS. CID: ', newTaskTypes[i])
              continue;
            }
            else {
            }

            taskObject.id = taskObjects.length;
            taskObject.IPFS = newTaskTypes[i];
            let fields = [];
            for (let i =0; i < taskObject.fields; i++){
                fields.push({"type": "text", "id": i})
            }
            taskObject.fields = fields;
            taskObjects.push(taskObject);
          }

          taskObjects.sort((a, b) => (a.id - b.id));
          setTaskTypes(taskObjects);
      }

      else {
        console.error("Not connected.");
      }
        isLoadingMyTasks = false;
    }


function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

  async function handleNewTaskSubmission() {
      alert("received: ", newTaskDescription);
      // create proposal or Task
  }


  async function DeleteTaskType(CID, numFields) {
    let tx = await wizardGovernanceContract.deleteTaskTypeByIPFSHash(CID);
    let res = await tx.wait(1);
    if(res){
        LoadMyTasks();
    }
  }


  async function CreateProposal(description, numFields) {
    console.log("details: ", description, numFields);
//    sendFileToIPFS(myFile);

    /// IPFS
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
            "name": description.slice(0, 80),
            "description": description,
            "fields": numFields
              }
        });
      let ipfsHash = (await sendFileToIPFS(data)).IpfsHash;

      let currentTime = parseInt(Date.now()/1000);
      let endTime = currentTime +  7*3600*24;
      let timeBonus = 24*60*60; // 1 day

      // Send to contract
      if(ipfsHash!=undefined){
        let tx = await wizardGovernanceContract.createProposal(ipfsHash, numFields, timeBonus, 0, endTime, 2*40-1);
        let res = await tx.wait(1);
        // update state
      }

  }

  async function CreateTask(description, numFields, maxSlots) {

    // IPFS
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
            "name": description.slice(0, 80),
            "description": description,
            "fields": numFields
              }
        });
      let ipfsHash = (await sendFileToIPFS(data)).IpfsHash;

      let currentTime = parseInt(Date.now()/1000);
      let endTime = currentTime +  7*3600*24;

      // Send to contract
      // todo -- get timeBonus from user
      let timeBonus = 24*60*60; // 1 day


//        console.log("infor for createTaskType: ", ipfsHash, numFields, timeBonus, endTime, maxSlots)
      if(ipfsHash!=undefined){
        let tx = await wizardGovernanceContract.createTaskType(ipfsHash, numFields, timeBonus, 0, endTime, maxSlots);
        let res = await tx.wait(1);
        if(res){
          // refresh
          LoadMyTasks();
        }
        else{
          // todo -- clean up unused IPFS data
        }
        // todo -- if res == fail, pull out the IPFS data
        // update state
      }

  }

  async function DeleteTaskType() {
    console.log("to do");
  }

// Request task to confirm
// confirmTask

  async function updateTaskToConfirmGivenInput(_input, _fieldId) {
    let myObj = Object.assign({}, taskToConfirm);
    myObj.fields[_fieldId].input = _input;
    setTaskToConfirm(myObj);
  }


  async function LoadTextFieldOntoConfirmingTask(confirmationObject) {
//       let confirmationObject = taskToConfirm;
       console.log("-------------IN LoadTextFieldOntoConfirmingTask ---------")
       console.log("confirmationObject: ", confirmationObject);

    if(confirmationObject.IPFSHash===undefined){
      return {}
    }

       let myJSON= await loadJSONFromIPFS(confirmationObject.IPFSHash);
       console.log("myJSON: ", myJSON);
       if(myJSON!= null && myJSON.description!=""){
         confirmationObject.description = myJSON.description;
         // create fields from numFields
         confirmationObject.fields = [];
         confirmationObject.inputs = [];
         for (let i =0; i<confirmationObject.numFields; i++){
            let obj = {"id": i, "type": "string", "input": ""}
            confirmationObject.fields.push(obj);
         }
//         new Array(confirmationObject.numFields).fill('string');

         console.log("confirmationObject: ", confirmationObject)
//         setTaskToConfirm(confirmationObject);
         return confirmationObject;
       }
       else{
         console.log("Call to IPFS failed to retrieve proper description.")
       }

  }

  async function updateOnBoard() {
    let _onBoard = await wizardGovernanceContract.isMyWizardOnBoard(wizardId);
    setOnBoard(_onBoard)
  }

    // a lot of await
  async function ClaimRandomTask() {
    setAreTasksAvailableToConfirm(false);
    let tx = await wizardGovernanceContract.claimRandomTaskForVerification(wizardId);
    let res = await tx.wait(1);
    console.log("res: ", res);
    if(res){
        console.log("res.events[0].args: ", res.events[0].args);
        // emit VerificationAssigned(_wizID, taskId, tasks[taskId]);
        let taskId = res.events[0].args[1]
        // note, we are passing task information in event
        let taskFromEvent = res.events[0].args[2];
        // todo -- this may needs to be formatted better

//        let task = await wizardGovernanceContract.getTaskById(taskId);

        // todo -- this is causing undefined
        let task = {"taskId": taskId, "IPFSHash": taskFromEvent.IPFSHash, "numFields": taskFromEvent.numFieldsToHash, "refuted": parseInt(taskFromEvent.refuterID)!=0}
        console.log("task after making it an object: ", task)
        // set stateVariable about tasks to confirm
        task = await LoadTextFieldOntoConfirmingTask(task);
        console.log("my new task: ", task)
        setTaskToConfirm(task);

//        console.log("taskId, task: ", taskId, task);

        // create function tasks assigned to me
    }
    else {
      console.log("error claiming task.")
      setAreTasksAvailableToConfirm(true);
    }

}

  async function ConfirmCompletedTask() {
    console.log("to do");
//    let myObj = Object.assign({}, taskToConfirm);
//    myObj.fields[_fieldId].input = _input;
//    setTaskToConfirm(myObj);

    let leaves = [];
    for(let i =0; i< taskToConfirm.fields.length; i++){
      leaves.push(taskToConfirm.fields[i].input);
    }

    let unhashedLeaves = []
//    let hashedLeaves = []
    let onceHashedLeaves = []
    let twiceHashedLeaves = []
//    let hashTypes = []
    // hash all leafs
    for(let i =0; i < leaves.length; i++){
        let temp = utils.keccak256(utils.toUtf8Bytes(leaves[i]))
        onceHashedLeaves.push(utils.keccak256(utils.toUtf8Bytes(leaves[i])));
        temp = utils.keccak256(temp);
        twiceHashedLeaves.push(temp);
//        hashTypes.push("bytes");
    }

    let finalHash;
    let tx = undefined;
    console.log("to send: ", wizardId, taskToConfirm.taskId, twiceHashedLeaves, onceHashedLeaves)
    if(taskToConfirm.refuted){
//        finalHash = ethers.utils.solidityKeccak256(hashTypes, twiceHashedLeaves)
        tx = await wizardGovernanceContract.submitVerification(wizardId, taskToConfirm.taskId, twiceHashedLeaves) ;
    }
    else{
//        finalHash = ethers.utils.solidityKeccak256(hashTypes, onceHashedLeaves)
        tx = await wizardGovernanceContract.submitVerification(wizardId, taskToConfirm.taskId, onceHashedLeaves) ;
    }


    let res = await tx.wait(1);
    console.log("res: ", res);
    console.log("res.events[0].args: ", res.events[0].args);

    if(res){
        setTaskToConfirm({});
    }

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
        if(activeTask!=undefined && taskTypes[activeTask]!=undefined){
//         console.log("activated task has changed. New num of fields: ", taskTypes[activeTask].fields.length, taskTypes[activeTask], activeTask)
         // resize myInputs
         let tempMyInputs = Array(taskTypes[activeTask].fields.length).fill('');
//         console.log("inputs have been created: ", tempMyInputs)
         setMyInputs(tempMyInputs);
        }
    }, [activeTask]);

    useEffect(() => {
        LoadMyTasks();
    }, [address]);

/*
    useEffect(() => {
        console.log("task to confirm has changed: ", taskToConfirm)
    }, [taskToConfirm]);
*/


/*
    useEffect(() => {
        console.log("taskToConfirm changed: ", taskToConfirm)
        if(areTasksAvailableToConfirm){
           console.log("loading text file...")
//           LoadTextFieldOntoConfirmingTask();
        }
    }, [areTasksAvailableToConfirm]);
*/

    useEffect(() => {
      LoadContracts();

    }, []);

    useEffect(() => {
      if(contractsLoaded===true){
         LoadMyTasks();
         updateAreTasksAvailableToConfirm();
         updatePendingTasksToConfirm();
         updateOnBoard();
      }
    }, [contractsLoaded]);

  return (
    <div className="">
      <div>

          {/* Board Functions*/}
          {onBoard && <div>
              <p> Board Functions </p>

              {/* Create Task */}
            <div>
                <textarea value={newTaskDescription} onChange={(e) => { setNewTaskDescription(e.target.value);}} />
                  <label for="numFields"> Num Fields</label>
                  <input
                    id="numFields"
                    type="number"
                    value={numFieldsForTask}
                    onChange={e => {
                      setNumFieldsForTask(Number(e.target.value));
                    }}
                  />

                  <label for="maxSlots"> Max Slots</label>
                  <input
                    type="number"
                    id="maxSlots"
                    value={maxSlotsForTask}
                    onChange={e => {
                      setMaxSlotsForTask(Number(e.target.value));
                    }}
                  />
                <button onClick={() => CreateTask(newTaskDescription, numFieldsForTask, maxSlotsForTask)}> Create Task Type </button> {/* description, beg timestamp, end timestamp*/}
            </div>

              {/* Create Propsoal */}
                <br />
            <div>
                <textarea value={newProposalDescription} onChange={(e) => { setNewProposalDescription(e.target.value);}} />
                  <label for="numFields"> Num Fields</label>
                  <input
                    type="number"
                    id="numFields"
                    value={numFieldsForProposal}
                    onChange={e => {
                      //bug
                      setNumFieldsForProposal(Number(e.target.value));
                    }}
                  />
                <button onClick={() => CreateProposal(newProposalDescription, numFieldsForProposal)}> Create Proposal </button> {/* description, num choices, beg timestamp, end timestamp*/}
            </div>

            {/* IPFSCidToDelete */}
                <br />
            <div>
                  <label for="numFields">IPFS Cid</label>
                  <input
                    type="text"
                    id="IPFSCIDField"
                    value={IPFSCidToDelete}
                    onChange={e => {
                      //bug
                      setIPFSCidToDelete(e.target.value);
                    }}
                  />
              <button onClick={() => DeleteTaskType(IPFSCidToDelete)}> Delete TaskType </button>
            </div>
        </div> } {/* End Admin Options */}

        {/* Authenticated User  Options */}
{/*
          <form onSubmit={this.HandleNewTaskSubmission}>
            <label>
              Description:
              <textarea value={this.state.newProposalDescription} onChange={this.HandleNewTaskDescriptionChange} />        </label>
            <input type="submit" value="Submit" />
          </form>
*/}
      </div>
      <h1>Available Tasks</h1>
        <div className="tasks-container">
          {taskTypes && taskTypes.map(taskType =>
            <div className="task-container" key={taskType.id}>
                <br/>

                {/* add line break if giving description, otherwise not */}
                {activeTask==taskType.id ? <br/> : ""}

                {activeTask==taskType.id ?
                    <div>
                       {/* <div>IPFS Link: {taskType.IPFS}</div>  */}
                        <div>Assignment: {taskType.description}</div>

                       {/* Input Fields  */}
                        {taskType.fields && taskType.fields.map(field =>
                            <div key={field.id} className="task">
                                <label> {field.id}: </label>
                                <input
                                    type={field.type}
                                    id={field.id}
                                    value={myInputs[parseInt(field.id)]}
                                    onChange={e => {handleUserInputChange(e.target.value, field.id)}}
                                />
                            </div>
                        )}

                        <div>
                           <button onClick={() => CompleteTask(taskType.id)}> Complete </button>
                        </div>
                    </div>
                :
                    <>
                       {/* Describe Task if not active, ability to activate */}
                       Task {taskType.id}, {taskType.name} <br/>
                       <button onClick={() => setActivedTask(taskType.id)}> Activate </button>
                    </>
                } {/*  End Individual Task Details  */}

            </div>
          )}
        </div>
        {areTasksAvailableToConfirm && taskToConfirm && (taskToConfirm.IPFSHash== undefined || taskToConfirm.IPFSHash=="" )
         ?
            <div>
               {taskToConfirm.IPFSHash}
               <button onClick={() => ClaimRandomTask()}> Claim Random Task to Confirm </button>
            </div>
         :
            <div>
               {/*No tasks available to confirm*/}
            </div>
         }

        {taskToConfirm && taskToConfirm.IPFSHash!=undefined && taskToConfirm.IPFSHash!=""  &&
            <>
                <h1>Tasks to Confirm</h1>
                <div className="tasks-container">

                    <div className="task-container">
                       {/* Input Fields  */}
                        {taskToConfirm.fields.map(field =>
                            <div key={field.id}>
                               {taskToConfirm.description} <br/>
                                <label> {field.id}: </label>
                                <input
                                    type={"string"}
                                    id={field.id}
                                    value={[field.input]}
                                    onChange={e => {updateTaskToConfirmGivenInput(e.target.value, field.id)}}
                                />
                            </div>
                        )}

                        <div>
                           <button onClick={() => ConfirmCompletedTask()}> Confirm Completed Task  </button>
                        </div>
                    </div>

                </div>
            </>
        }

        {address==null && "Please Connect"}
        {address!=null && (taskTypes == undefined) && 'loading...'}
    </div>
  );
}

export default Tasks;
