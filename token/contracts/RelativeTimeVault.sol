pragma solidity 0.8.15;
// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.8.0;

import '../contracts/helpers/Ownable.sol';
import '../contracts/helpers/ReentrancyGuard.sol';
import '../contracts/interfaces/IERC20.sol';
import '../contracts/interfaces/IERC721.sol';
import '../contracts/wizards.sol';
import "../contracts/libraries/PRBMathSD59x18Typed.sol";

contract RelativeTimeVault is ReentrancyGuard, Ownable {
  using PRBMathSD59x18Typed for PRBMath.SD59x18;
    //    using PRBMathUD60x18 for PRBMath.UD60x18;
    IERC20 public token; // Address of token contract and same used for rewards
    Wizards public wizardsNFT;


//    uint256 totalTowerPower; // sum of power of all rooms
    uint256 public activeFloors = 0; //  10000;
    uint256 public constant DA = 10**6; // Decimals Added for better accuracy
    uint256 startTimestamp;
    uint256 public totalPowerSnapshot;
    uint256 public totalPowerSnapshotTimestamp;
    uint256 DUST = 10**6; // min ecosystem tokens to do certain actions like auto withdraw

    // Geometric sequence
    uint256 aFirst = 10**10;
    uint256 relativeIncrease = 9990; // out of 10000

    address public tokenOperator; // Address to manage the Stake
    address public battler; // Address to manage the Stake
//    enum Wizards.ELEMENT {FIRE, WIND, WATER, EARTH}

    // todo -- combine mappings
    struct FloorInfo {
        uint16 floorPower; // todo -- may not use it this way (function, instead)
        uint40 lastWithdrawalTimestamp;
        uint16 occupyingWizardId;
        Wizards.ELEMENT element;
    }
//    struct FloorPlans {
//        uint16 begin;
//        uint16 end;
//    }


//    mapping (address => uint256) public floorPower; // Relative user Token balance in the contract
//    mapping (address => uint256) public lastWithdrawalTimestamp; // Relative user Token balance in the contract

    mapping (uint256 => FloorInfo) public floorIdToInfo; // floor id to floor info
    mapping (uint256 => uint256 ) public wizardIdToFloor; // floor 0 DNE
//    FloorPlans[] public floorPlans;

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

    // todo -- consider having this an array
    modifier onlyBattler() {
        require(
            msg.sender == battler,
            "Only battler can call this function."
        );
        _;
    }


    /////////////////////
    ////    TEMP       //
    /////////////////////

  /// @notice Calculates x*y÷1e18 while handling possible intermediary overflow.
  /// @dev Try this with x = type(uint256).max and y = 5e17.
  function unsignedMul(uint256 x, uint256 y) external pure returns (uint256 result) {
//    result = x.mul(y);
    result = 9999;
  }


  function unsignedPow(uint256 x, uint256 y) external pure returns (uint256 result) {
//    result = x.pow(y);
    result = 8888;
  }

  function doTheMath() external pure returns (int256 result) {
    uint256 x = 9993*10**14;
    uint256 y = 1000*10**18;
//    result = (x).pow(y);

    PRBMath.SD59x18 memory xsd = PRBMath.SD59x18(int256(x));
    PRBMath.SD59x18 memory ysd = PRBMath.SD59x18(int256(y));
    result = xsd.pow(ysd).value;

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

    function getFloorGivenWizard(uint256 _wizardId) external view returns(uint256

    ) {
        require(_wizardId>0 && _wizardId < activeFloors + 1, "invalid number");
        return wizardIdToFloor[_wizardId];
    }

    //////////////
    ////  Core  //
    //////////////

    constructor(address _token, address _wizardsNFTAddress)
    {
        token = IERC20(_token);
        wizardsNFT = Wizards(_wizardsNFTAddress);
        tokenOperator = msg.sender;
        battler = msg.sender;
        startTimestamp = block.timestamp;
        totalPowerSnapshotTimestamp = block.timestamp;
    }

    // todo -- reconsider functionality of operator, owner
    function updateOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0) && newOperator != tokenOperator, "Invalid operator address");
        tokenOperator = newOperator;
        emit NewOperator(newOperator);
    }

    function updateBattler(address _battler) external onlyOwner {
        require(_battler != address(0) && _battler != battler, "Invalid operator address");
        battler = _battler;
        emit NewBattler(_battler);
    }


    // For migration
    function drainTower() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(msg.sender, balance), "Unable to transfer token back to the account");
        emit DrainTower(msg.sender, balance);
    }

    // claim floor for wizard. Returns floor on.
    function claimFloor(uint256 _wizardId) external returns (uint256) {
        require(wizardsNFT.ownerOf(_wizardId)==msg.sender, "must own wizardsNFT");
        require(wizardIdToFloor[_wizardId] == 0, "already claimed.");
        activeFloors += 1;
        FloorInfo memory floorInfo;
        floorInfo.lastWithdrawalTimestamp = uint40(block.timestamp);
        floorInfo.element = Wizards.ELEMENT(uint256(keccak256(abi.encodePacked(activeFloors, msg.sender, block.timestamp))) % 4);
        floorInfo.occupyingWizardId = uint16(_wizardId);
        wizardIdToFloor[_wizardId] = activeFloors;
        floorIdToInfo[activeFloors] = floorInfo;
        _updateTotalPowerSnapshot(0);
        emit FloorClaimed(msg.sender, activeFloors, _wizardId, block.timestamp);
        return activeFloors;
    }

    function captureFloor(uint256 _floorCaptured) external onlyBattler {
        uint256 capturedId = floorIdToInfo[_floorCaptured].occupyingWizardId;
        uint256 bottom =   floorIdToInfo[activeFloors].occupyingWizardId;
        if(floorBalance(activeFloors) > DUST) {
            _withdraw(activeFloors, wizardsNFT.ownerOf(bottom));
        }

        // put bottom wizard in attacking wizard spot
        FloorInfo storage floorCaptured = floorIdToInfo[_floorCaptured];
        floorCaptured.occupyingWizardId = uint16(bottom);
        floorCaptured.lastWithdrawalTimestamp = uint40(block.timestamp);


        activeFloors -= 1;
        _updateTotalPowerSnapshot(0); // reductions happened automatically in withdraw
    }

//    // removes deserter from tower
//    // todo -- note, there is no option for battler and so could combine this as only external function
//    // todo -- consider reducing number of state changes
//    function _captureFloor(uint256 _floorAttacked, uint256 _floorAttackedFrom) internal {
//        uint256 defender = floorIdToInfo[_floorAttacked].occupyingWizardId;
//        uint256 attacker = floorIdToInfo[_floorAttackedFrom].occupyingWizardId;
//        uint256 bottom =   floorIdToInfo[activeFloors].occupyingWizardId;
//
//        require(wizardsNFT.isActive(defender) == false && wizardsNFT.isActive(attacker) == true, "def must be inactive; att active");
//
//        // happens within battle or separate?
//        // drain current floor for attacking wizard
//        if(floorBalance(_floorAttackedFrom) > DUST) {
//            _withdraw(_floorAttackedFrom, wizardsNFT.ownerOf(attacker));
//        }
//        // drain captured floor to attacking wizard
//        if(floorBalance(_floorAttacked) > DUST) {
//            _withdraw(_floorAttacked, wizardsNFT.ownerOf(attacker));
//        }
//        // drain bottom floor to bottom wizard
//        if(floorBalance(activeFloors) > DUST) {
//            _withdraw(activeFloors, wizardsNFT.ownerOf(bottom));
//        }
//
//        // put attacking wizard in attacking floor
//        FloorInfo storage floorAttacked = floorIdToInfo[_floorAttacked];
//        floorAttacked.occupyingWizardId = uint16(attacker);
//        floorAttacked.lastWithdrawalTimestamp = uint40(block.timestamp);
//
//        // put bottom wizard in attacking wizard spot
//        FloorInfo storage floorAttackedFrom = floorIdToInfo[_floorAttackedFrom];
//        floorAttackedFrom.occupyingWizardId = uint16(bottom);
//        floorAttackedFrom.lastWithdrawalTimestamp = uint40(block.timestamp);
//
//        // floorIdToInfo[activeFloors] still points to bottom, but will be rewritten when new floor is activated
//
//        activeFloors -= 1;
//        _updateTotalPowerSnapshot(0); // reductions happened automatically in withdraw
//    }

    function switchFloors(uint256 _floorA, uint256 _floorB) external onlyBattler {
        require((_floorA <= activeFloors) && (_floorB <= activeFloors) && (_floorB != _floorA), "invalid floors");
        FloorInfo memory floorInfo;
        uint256 previousFloorAWizard = floorIdToInfo[_floorA].occupyingWizardId;
        floorIdToInfo[_floorA].occupyingWizardId = floorIdToInfo[_floorB].occupyingWizardId;
        floorIdToInfo[_floorB].occupyingWizardId = uint16(previousFloorAWizard);
        wizardIdToFloor[floorIdToInfo[_floorA].occupyingWizardId] = _floorA;
        wizardIdToFloor[previousFloorAWizard] = _floorB;
    }


    function floorBalance(uint256 _floor) public view returns(uint256) {
        return _floorBalance(_floor);
    }

    function _floorBalance(uint256 _floor) internal view returns(uint256) {
        require(activeFloors>0, "no active floors");
        require(_floor <= activeFloors && _floor!= 0, "invalid floor");
        FloorInfo memory floorInfo = floorIdToInfo[_floor];

        return floorPower(_floor) * token.balanceOf((address(this))) / _totalFloorPower();
    }

    // todo -- implement geometric series powered by: https://github.com/paulrberg/prb-math
    // todo -- tutorial -- https://www.smartcontractresearch.org/t/deep-diving-into-prbmath-a-library-for-advanced-fixed-point-math/686
    function floorPower(uint256 _floor) public view returns(uint256) {
        // Geometric series -- todo
//        return aFirst * (relativeIncrease ** (_floor - 1)); // A(n) for geometric series

//        Temporary simple series using one value (aFirst) for all floor powers base units (not including time)
        FloorInfo memory floorInfo = floorIdToInfo[_floor];

        // use startTimestamp if never withdrawn
        uint256 timestamp = floorInfo.lastWithdrawalTimestamp == 0 ? startTimestamp : floorInfo.lastWithdrawalTimestamp;
        return aFirst * (block.timestamp - timestamp);
    }

    function _totalFloorPower() public view returns(uint256) {
        // Geometric series -- todo
        return totalPowerSnapshot + (block.timestamp - totalPowerSnapshotTimestamp) * aFirst * activeFloors;
    }

    // called when adding/removing floors or withdrawing
    function _updateTotalPowerSnapshot(uint256 _powerRemoved) internal  {
        totalPowerSnapshot = _totalFloorPower() - _powerRemoved;
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