pragma solidity ^0.8.4;
// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.8.0;

import '../contracts/helpers/Ownable.sol';
import '../contracts/helpers/ReentrancyGuard.sol';
import '../contracts/interfaces/IERC20.sol';
import '../contracts/interfaces/IERC721.sol';

contract RelativeTimeVault is ReentrancyGuard, Ownable {
    IERC20 public token; // Address of token contract and same used for rewards
    IERC721 public NFT;

    uint256 totalTowerPower; // sum of power of all rooms
    uint256 public activeFloors = 0; //  10000;
    uint256 public constant DA = 10**6; // Decimals Added for better accuracy
    uint256 startTimestamp;

    address public tokenOperator; // Address to manage the Stake
    address public switcher; // Address to manage the Stake
    enum ELEMENT {FIRE, WIND, WATER, EARTH}

    // todo -- combine mappings
    struct FloorInfo {
        uint16 floorPower; // todo -- may not use it this way (function, instead)
        uint40 lastWithdrawalTimestamp;
        uint16 occupyingWizardId;
        ELEMENT element;
    }
    struct FloorPlans {
        uint16 begin;
        uint16 end;
    }


//    mapping (address => uint256) public floorPower; // Relative user Token balance in the contract
//    mapping (address => uint256) public lastWithdrawalTimestamp; // Relative user Token balance in the contract

    mapping (uint256 => FloorInfo) public floorIdToInfo; // floor id to floor info
    mapping (uint256 => uint256 ) public wizardIdToFloor; // floor 0 DNE
    FloorPlans[] public floorPlans;

    // Events
    event NewOperator(address tokenOperator);
    event NewSwitcher(address switcher);
    event DrainTower(address indexed tokenOperator, uint256 amount);
    event Withdraw(address indexed staker, uint256 totalAmount);

    // Modifiers
    modifier onlyOperator() {
        require(
            msg.sender == tokenOperator,
            "Only operator can call this function."
        );
        _;
    }

    // todo -- consider having this an array
    modifier onlySwitcher() {
        require(
            msg.sender == switcher,
            "Only switcher can call this function."
        );
        _;
    }


    ////////////////////
    ////    Get       //
    ////////////////////

    function isOnTheTower(uint256 _wizardId) external returns(bool) {
        return wizardIdToFloor[_wizardId] != 0;
    }

    function getWizardOnFloor(uint256 _floor) external returns(uint256) {
        return uint256(floorIdToInfo[_floor].occupyingWizardId);
    }


    //////////////
    ////  Core  //
    //////////////

    constructor(address _token, address _NFTAddress)
    {
        token = IERC20(_token);
        NFT = IERC721(_NFTAddress);
        tokenOperator = msg.sender;
        switcher = msg.sender;
        startTimestamp = block.timestamp;
    }

    // todo -- reconsider functionality of operator, owner
    function updateOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0) && newOperator != tokenOperator, "Invalid operator address");
        tokenOperator = newOperator;
        emit NewOperator(newOperator);
    }

    function updateSwitcher(address _switcher) external onlyOwner {
        require(_switcher != address(0) && _switcher != switcher, "Invalid operator address");
        switcher = _switcher;
        emit NewSwitcher(_switcher);
    }


    // For migration
    function drainTower() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(msg.sender, balance), "Unable to transfer token back to the account");
        emit DrainTower(msg.sender, balance);
    }

    // claim floor for wizard
    function claimFloor(uint256 _wizardId) external returns (uint256) {
        require(true, "must own NFT"); // todo implement
        require(wizardIdToFloor[_wizardId] == 0, "already claimed.");
        activeFloors += 1;
        FloorInfo memory floorInfo;
        floorInfo.lastWithdrawalTimestamp = uint40(block.timestamp);
        floorInfo.element = ELEMENT(uint(keccak256(abi.encodePacked(activeFloors, msg.sender, block.timestamp))) % 4);
        floorInfo.occupyingWizardId = uint16(_wizardId);
        wizardIdToFloor[_wizardId] = activeFloors;
        floorIdToInfo[activeFloors] = floorInfo;
        return activeFloors;
    }

    function switchFloors(uint256 _floorA, uint256 _floorB) external onlySwitcher {
        require((_floorA <= activeFloors) && (_floorB <= activeFloors) && (_floorB != _floorA), "must own NFT");
        FloorInfo memory floorInfo;
        uint256 previousFloorAWizard = floorIdToInfo[_floorA].occupyingWizardId;
        floorIdToInfo[_floorA].occupyingWizardId = floorIdToInfo[_floorB].occupyingWizardId;
        floorIdToInfo[_floorB].occupyingWizardId = uint16(previousFloorAWizard);
        wizardIdToFloor[floorIdToInfo[_floorA].occupyingWizardId] = _floorA;
        wizardIdToFloor[previousFloorAWizard] = _floorB;
    }


    // todo -- make it so this conforms to active floors
    // todo -- make sure these are sorted
    function createFloorPlans(uint16[] memory _floorPlans) external onlyOwner {
        require((_floorPlans.length !=0) && (_floorPlans.length %2 == 0), "invalid floor plan");
//        floorPlans = new FloorPlans[](_floorPlans.length/2);
        delete floorPlans;
//        = new FloorPlans[];
        FloorPlans memory tempPlan;
        for(uint256 i = 0; i < _floorPlans.length;) {
            tempPlan.begin = _floorPlans[i];
            tempPlan.end = _floorPlans[i+1];
            floorPlans.push(tempPlan);
            unchecked{ i= i+2; }
        }


        //        emit NewFloorPlans(); // todo create event
    }

    function floorBalance(uint256 _floor) public view returns(uint256) {
        return _floorBalance(_floor);
    }

    function floorPower(uint256 _floor) public view returns(uint256) {
        uint256 sharedFloors;
        for(uint256 i = 0; i < floorPlans.length;) {
            if(floorPlans[i].begin <= _floor && _floor <= floorPlans[i].end){
                sharedFloors = floorPlans[i].end - floorPlans[i].begin + 1;
                break;
            }
            unchecked{ i++; }
        }
        return DA / activeFloors / sharedFloors; // todo -- this is going to result in zero. Need to add in extra 10^x
        return _floorBalance(_floor);
    }


    // may be used to show balance on NFT
//    function floorBalance() external view returns(uint256) {
//        require(true, "must own NFT"); // todo confirm owns NFT
//        uint256 myFloor; // todo
//        return _floorBalance(0); // todo -- get floor of user
//    }

    function _floorBalance(uint256 _floor) internal view returns(uint256) {
        require(_floor < activeFloors);
        FloorInfo memory floorInfo = floorIdToInfo[_floor];

        // use startTimestamp if never withdrawn
        uint256 timestamp = floorInfo.lastWithdrawalTimestamp == 0 ? startTimestamp : floorInfo.lastWithdrawalTimestamp;
        return (block.timestamp - timestamp) * floorPower(_floor) * token.balanceOf((address(this))) /
               ((block.timestamp - startTimestamp) * activeFloors) / DA;
    }

    function withdraw(uint256 _floor) external nonReentrant {
        // todo -- require wizard is at that floor
        require(true, "wizard not at that floor");
        //
        uint256 amountToWithdraw = _floorBalance(_floor);
        // _withdrawFromVault
        // _withdrawFromVault(amountToWithdraw); // we don't want to add our tokens to a vault atm

        // Check for balance in the contract
        require(token.balanceOf(address(this)) >= amountToWithdraw, "Not enough balance in the contract");

        // Update timestamp
        floorIdToInfo[_floor].lastWithdrawalTimestamp = uint40(block.timestamp);

        // Call the transfer function
        require(token.transfer(msg.sender, amountToWithdraw), "Unable to transfer token back to the account");

        emit Withdraw(msg.sender, amountToWithdraw);
    }


//    function _addToVault(uint256 _amount) virtual internal {
//        // todo -- rewrite this to add funds to any vault, LP, etc.
//        // if no external vault, no need to do anything
//    }
//
//    function _withdrawFromVault(uint256 amount) virtual internal {
//        // todo -- rewrite this to remove funds to any vault, LP, etc.
//        // if no external vault, no need to do anything
//    }
//
//    function totalVaultBalance() virtual public returns (uint256){
//        return token.balanceOf(address(this));
//    }




}