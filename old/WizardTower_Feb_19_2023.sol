pragma solidity 0.8.15;
// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.8.0;

import '../contracts/helpers/Ownable.sol';
import '../contracts/helpers/ReentrancyGuard.sol';
import '../contracts/interfaces/IERC20.sol';
import '../contracts/interfaces/IERC721.sol';
import '../contracts/wizards.sol';
//import "../contracts/libraries/PRBMathSD59x18Typed.sol";


// todo -- we can drop the idea of floors and just have wizards in the tower, since all "floors" are now equal

contract WizardTower is ReentrancyGuard, Ownable {
    IERC20 public token; // Address of token contract and same used for rewards
    Wizards public wizardsNFT;

    // make contract Settings struct
    uint256 public activeFloors;
    uint256 startTimestamp;
    uint256 public totalPowerSnapshot;
    uint256 public totalPowerSnapshotTimestamp;
//    uint256 DUST = 10**6; // min ecosystem tokens to do certain actions like auto withdraw

    address public tokenOperator; // Address to manage the Stake
    address public battler; // Address to manage the Stake
//    enum Wizards.ELEMENT {FIRE, WIND, WATER, EARTH}

/*
    struct ContractSettings {
        uint16 activeFloors;
        uint40 startTimestamp;
        uint128 totalPowerSnapshot;
        uint40 totalPowerSnapshotTimestamp;
    //    uint40 dust = 10**6; // min ecosystem tokens to do certain actions like auto withdraw
        address tokenOperator; // Address to manage the Stake
        address battler; // Address to manage the Stake
    }
    ContractSettings public contractSettings;
*/

    // todo -- combine mappings
    struct FloorInfo {
        uint40 lastWithdrawalTimestamp;
        uint16 occupyingWizardId;
    }

    mapping (uint256 => FloorInfo) public floorIdToInfo; // floor id to floor info
    mapping (uint256 => uint256 ) public wizardIdToFloor; // floor 0 DNE


    // Events
    event NewOperator(address tokenOperator);
    event NewBattler(address battler);
    event DrainTower(address indexed tokenOperator, uint256 amount);
    event Withdraw(address indexed staker, uint256 totalAmount);
    event FloorClaimed(address claimer, uint256 floorClaimed, uint256 indexed wizardId, uint256 timestamp);

    // Modifiers
    modifier onlyOperator() {
        require(
            msg.sender == tokenOperator,
            "Only operator can call this function."
        );
        _;
    }

    ////////////////////
    ////    Get       //
    ////////////////////

    function isOnTheTower(uint256 _wizardId) external view returns(bool) {
        return wizardIdToFloor[_wizardId] != 0;
    }

    function getWizardOnFloor(uint256 _floor) external view returns(uint256) {
        return uint256(floorIdToInfo[_floor].occupyingWizardId);
    }

    function getFloorInfoGivenFloor(uint256 _floor) external view returns(FloorInfo memory) {
        return floorIdToInfo[_floor];
    }

    function getFloorInfoGivenWizard(uint256 _wizardId) external view returns(FloorInfo memory) {
        require(_wizardId>0 && _wizardId < activeFloors + 1, "invalid number");
        return floorIdToInfo[wizardIdToFloor[_wizardId]];
    }

    function getFloorGivenWizard(uint256 _wizardId) external view returns(uint256) {
        require(_wizardId>0 && _wizardId < activeFloors + 1, "invalid number");
        return wizardIdToFloor[_wizardId];
    }

    function floorBalance(uint256 _floor) public view returns(uint256) {
        return _floorBalance(_floor);
    }

    /// todo review for accuracy
    function _floorBalance(uint256 _floor) internal view returns(uint256) {
        require(activeFloors>0, "no active floors");
        require(_floor <= activeFloors && _floor!= 0, "invalid floor");
//        FloorInfo memory floorInfo = floorIdToInfo[_floor];
        return floorPower(_floor) * token.balanceOf((address(this))) / totalFloorPower();
    }


    //////////////
    ////  Core  //
    //////////////

    constructor(address _token, address _wizardsNFTAddress)
    {
        token = IERC20(_token);
        wizardsNFT = Wizards(_wizardsNFTAddress);
        tokenOperator = msg.sender;
        startTimestamp = block.timestamp;
        totalPowerSnapshotTimestamp = block.timestamp;
    }

    function updateOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0) && newOperator != tokenOperator, "Invalid operator address");
        tokenOperator = newOperator;
        emit NewOperator(newOperator);
    }

    // For migration
    function drainTower() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(msg.sender, balance), "Unable to transfer token back to the account");
        emit DrainTower(msg.sender, balance);
    }

    // claim floor for wizard. Returns floor on.
    function claimFloor(uint256 _wizardId) external returns (uint256) {
        require(wizardsNFT.isMature(_wizardId) && wizardsNFT.ownerOf(_wizardId)==msg.sender, "must own mature wizardsNFT");
        require(wizardIdToFloor[_wizardId] == 0, "already claimed.");
        activeFloors += 1;
        FloorInfo memory floorInfo;
        floorInfo.lastWithdrawalTimestamp = uint40(block.timestamp);
//        floorInfo.element = Wizards.ELEMENT(uint256(keccak256(abi.encodePacked(activeFloors, msg.sender, block.timestamp))) % 4);
        floorInfo.occupyingWizardId = uint16(_wizardId);
        wizardIdToFloor[_wizardId] = activeFloors;
        floorIdToInfo[activeFloors] = floorInfo;
        _updateTotalPowerSnapshot(0);
        emit FloorClaimed(msg.sender, activeFloors, _wizardId, block.timestamp);
        return activeFloors;
    }

    // todo -- update or remove. There should be a new function to withdraw wizard from the tower
    function switchFloors(uint256 _floorA, uint256 _floorB) internal {
        require((_floorA <= activeFloors) && (_floorB <= activeFloors) && (_floorB != _floorA), "invalid floors");
//        FloorInfo memory floorInfo;
        uint256 previousFloorAWizard = floorIdToInfo[_floorA].occupyingWizardId;
        floorIdToInfo[_floorA].occupyingWizardId = floorIdToInfo[_floorB].occupyingWizardId;
        floorIdToInfo[_floorB].occupyingWizardId = uint16(previousFloorAWizard);
        wizardIdToFloor[floorIdToInfo[_floorA].occupyingWizardId] = _floorA;
        wizardIdToFloor[previousFloorAWizard] = _floorB;
    }

//    function testFloorPower(uint256 _floor) external view returns(uint256) {
//        uint256 myPower = 10**18;
//        FloorInfo memory floorInfo = floorIdToInfo[_floor];
//        uint256 timestamp = floorInfo.lastWithdrawalTimestamp == 0 ? startTimestamp : floorInfo.lastWithdrawalTimestamp;
//        return myPower * (block.timestamp - timestamp);// / 10**18;
//    }

    function drainAndDropFromFloor(uint256 _floor) external onlyOwner returns(uint256) {
        // todo -- confirm accurate _floor
        // drain funds from floor and send to DAO
        // replace wizard in this floor with bottom floor
        switchFloors(_floor, activeFloors);
        // decrease total floors
        activeFloors -= 1;

        return 999999;
    }


    function floorPower(uint256 _floor) public view returns(uint256) {
        require(_floor > 0 && _floor <= activeFloors, "invalid floor");
//        uint256 myPower = 1;
        FloorInfo memory floorInfo = floorIdToInfo[_floor];
        // use startTimestamp if never withdrawn
        uint256 timestamp = floorInfo.lastWithdrawalTimestamp == 0 ? startTimestamp : floorInfo.lastWithdrawalTimestamp;
//        return myPower * (block.timestamp - timestamp) / 10**18;
        return block.timestamp - timestamp;
    }

    function totalFloorPower() public view returns(uint256) {
        return totalPowerSnapshot + (block.timestamp - totalPowerSnapshotTimestamp) * activeFloors;
    }

    // called when adding/removing floors or withdrawing
    function _updateTotalPowerSnapshot(uint256 _powerRemoved) internal  {
        totalPowerSnapshot = totalFloorPower() - _powerRemoved;
        totalPowerSnapshotTimestamp = block.timestamp;
    }

    function withdraw(uint256 _floor) external nonReentrant {
        // require owner owns wizardsNFT on that floor
        require(_floor!= 0 && _floor <= activeFloors, "invalid floor");
        uint256 wizardId = floorIdToInfo[_floor].occupyingWizardId;
        require(wizardsNFT.ownerOf(wizardId) == tx.origin, "You do not own the wizard there."); // todo -- confirm tx.origin is ok
        _withdraw(_floor, tx.origin);
    }

    function _withdraw(uint256 _floor, address recipient) internal {
        uint256 amountToWithdraw = _floorBalance(_floor);
        uint256 myPower = floorPower(_floor);
        // _withdrawFromVault
        // _withdrawFromVault(amountToWithdraw); // we don't want to add our tokens to a vault atm

        // Check for balance in the contract
        require(token.balanceOf(address(this)) >= amountToWithdraw, "Not enough balance in the contract");

        // Update timestamp
        floorIdToInfo[_floor].lastWithdrawalTimestamp = uint40(block.timestamp);

        // Call the transfer function
        require(token.transfer(recipient, amountToWithdraw), "Unable to transfer token back to the account");

        _updateTotalPowerSnapshot(myPower);

        emit Withdraw(recipient, amountToWithdraw);
    }
}