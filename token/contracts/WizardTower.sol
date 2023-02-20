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

    uint128 public totalPowerSnapshot;
    uint40 public totalPowerSnapshotTimestamp;
    address public evictionProceedsReceiver; // Address to manage the Stake

//    enum Wizards.ELEMENT {FIRE, WIND, WATER, EARTH}


    struct ContractSettings {
        uint16 activeFloors;
        uint40 startTimestamp;
        uint16 floorCap;
        uint64 dustThreshold; // min ecosystem tokens to do certain actions like auto withdraw
        address evictionProceedsReceiver; // Address to manage the Stake
    }
    ContractSettings public contractSettings;


    // todo -- combine mappings
    struct FloorInfo {
        uint40 lastWithdrawalTimestamp;
//        uint16 occupyingWizardId;
    }

    mapping (uint256 => FloorInfo ) public wizardIdToFloorInfo; // floor 0 DNE


    // Events
    event DrainTower(address indexed owner, uint256 amount);
    event Withdraw(address indexed staker, uint256 totalAmount);
    event NewEvictionProceedsReceiver(address evictionProceedsReceiver);
    event FloorClaimed(address claimer, uint256 indexed wizardId);
    event NewFloorCap(uint16 floorCap);
    event NewDustThreshold(uint64 dustThreshold);
    event WizardEvicted(uint256 wizardId);

    ////////////////////
    ////    Get       //
    ////////////////////

    function isOnTheTower(uint256 _wizardId) public view returns(bool) {
        require(_wizardId !=0 && _wizardId <= wizardsNFT.totalSupply(), "invalid wizard");
        return wizardIdToFloorInfo[_wizardId].lastWithdrawalTimestamp != 0;
    }

    function getFloorInfoGivenWizard(uint256 _wizardId) external view returns(FloorInfo memory) {
        require(_wizardId>0 && _wizardId < contractSettings.activeFloors + 1, "invalid number");
        return wizardIdToFloorInfo[_wizardId];
    }

    function floorBalance(uint256 _floor) public view returns(uint256) {
        return _floorBalance(_floor);
    }

    function _floorBalance(uint256 _floor) internal view returns(uint256) {
//        require(isOnTheTower(_floor), "invalid floor or no occupant");
        require(_floor !=0 && _floor <= wizardsNFT.totalSupply(), "invalid floor"); // wizardId and floor are interchangeable
        uint256 _totalFloorPower = totalFloorPower();
        return _totalFloorPower == 0 ? 0 : floorPower(_floor) * token.balanceOf((address(this))) / _totalFloorPower;
    }

    //////////////
    ////  Core  //
    //////////////

    constructor(address _token, address _wizardsNFTAddress)
    {
        token = IERC20(_token);
        wizardsNFT = Wizards(_wizardsNFTAddress);
        totalPowerSnapshotTimestamp = uint40(block.timestamp);
        contractSettings.evictionProceedsReceiver = msg.sender;
        contractSettings.startTimestamp = totalPowerSnapshotTimestamp;
        contractSettings.floorCap = 10000;
        contractSettings.dustThreshold = uint64(10**16);
    }

    // For migration
    function drainTower() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(msg.sender, balance), "Unable to transfer token back to the account");
        emit DrainTower(msg.sender, balance);
    }

    // claim floor for wizard. Returns floor on.
    function claimFloor(uint256 _wizardId) external {
        require(wizardsNFT.isMature(_wizardId) && wizardsNFT.ownerOf(_wizardId)==msg.sender, "must own mature wizardsNFT");
        require(wizardIdToFloorInfo[_wizardId].lastWithdrawalTimestamp == 0, "already claimed");
        require(contractSettings.activeFloors < contractSettings.floorCap, "tower at max capacity");
        contractSettings.activeFloors += 1;
//        FloorInfo memory floorInfo;
//        floorInfo.lastWithdrawalTimestamp = uint40(block.timestamp);
//        wizardIdToFloorInfo[_wizardId] = floorInfo;
        wizardIdToFloorInfo[_wizardId].lastWithdrawalTimestamp = uint40(block.timestamp);
        _updateTotalPowerSnapshot(0);
        emit FloorClaimed(msg.sender, _wizardId);
    }

    function evict(uint256 _wizardId) external onlyOwner returns(uint256) {
        require(isOnTheTower(_wizardId), "not on tower");
        uint256 bal = _floorBalance(_wizardId);
        // todo -- we could have some amount be sent to DAO, some absorbed by all other wizards on tower
        if (bal > contractSettings.dustThreshold) {
            _withdraw(_wizardId, contractSettings.evictionProceedsReceiver);
        }
        else {
            // dust will be absorbed by all other users
            _updateTotalPowerSnapshot(floorPower(_wizardId));
        }

        delete wizardIdToFloorInfo[_wizardId];
        contractSettings.activeFloors -= 1;
        emit WizardEvicted(_wizardId);
        return bal;
    }


    function floorPower(uint256 _floor) public view returns(uint128) {
        require(isOnTheTower(_floor)); // floor is same as wizardId
        FloorInfo memory floorInfo = wizardIdToFloorInfo[_floor]; // wizard id is same as floor id
        uint256 timestamp = floorInfo.lastWithdrawalTimestamp == 0 ? contractSettings.startTimestamp : floorInfo.lastWithdrawalTimestamp;
        return uint128(block.timestamp - timestamp);
    }

    function totalFloorPower() public view returns(uint128) {
        return uint128(totalPowerSnapshot + (block.timestamp - totalPowerSnapshotTimestamp) * contractSettings.activeFloors);
    }

    // called when adding/removing floors or withdrawing
    function _updateTotalPowerSnapshot(uint128 _powerRemoved) internal  {
        totalPowerSnapshot = uint128(totalFloorPower() - _powerRemoved);
        totalPowerSnapshotTimestamp = uint40(block.timestamp);
    }

    function withdraw(uint256 _wizardId) external nonReentrant {
        // require owner owns wizardsNFT on that floor
        require(wizardsNFT.ownerOf(_wizardId) == tx.origin, "You do not own the wizard there."); // todo -- confirm tx.origin is ok
        _withdraw(_wizardId, tx.origin);
    }

    function _withdraw(uint256 _floor, address recipient) internal {
        require(isOnTheTower(_floor)); // floor is same as wizardId
        uint256 amountToWithdraw = _floorBalance(_floor);
        require(amountToWithdraw!=0, "nothing to withdraw");
        uint128 myPower = floorPower(_floor);
        // Check for balance in the contract
        require(token.balanceOf(address(this)) >= amountToWithdraw, "Not enough balance in the contract");

        // Update timestamp
        wizardIdToFloorInfo[_floor].lastWithdrawalTimestamp = uint40(block.timestamp);

        // Call the transfer function
        require(token.transfer(recipient, amountToWithdraw), "Unable to transfer token back to the account");

        // reduce total power by the power removed
        _updateTotalPowerSnapshot(myPower);

        emit Withdraw(recipient, amountToWithdraw);
    }

    /** @dev update address that receives funds from eviction
      * @param _evictionProceedsReceiver new address for culler, the wallet/contract which can exile wizards without contraint
      */
    function updateEvictionProceedsReceiver(address _evictionProceedsReceiver) external onlyOwner {
        require(_evictionProceedsReceiver != address(0) && _evictionProceedsReceiver != contractSettings.evictionProceedsReceiver, "Invalid operator address");
        contractSettings.evictionProceedsReceiver = _evictionProceedsReceiver;
        emit NewEvictionProceedsReceiver(_evictionProceedsReceiver);
    }

    /** @dev update max amount of occupants on tower
      * @param _floorCap max amount of occupants
      */
    function updateFloorCap(uint16 _floorCap) external onlyOwner {
        require(_floorCap != contractSettings.floorCap, "same cap");
        contractSettings.floorCap = _floorCap;
        emit NewFloorCap(_floorCap);
    }

    /** @dev update min token amount to transfer to EvictionProceedsReceiver
      * @param _dustThreshold max amount of occupants
      */
    function updateDustThreshold(uint64 _dustThreshold) external onlyOwner {
        require(_dustThreshold != contractSettings.dustThreshold, "same dust threshold");
        contractSettings.dustThreshold = _dustThreshold;
        emit NewDustThreshold(_dustThreshold);
    }

}