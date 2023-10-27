pragma solidity 0.8.15;
// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.8.0;

import "./helpers/console.sol";

import '../contracts/helpers/Ownable.sol';
import '../contracts/helpers/ReentrancyGuard.sol';
import '../contracts/interfaces/IERC20.sol';
import '../contracts/interfaces/IERC721.sol';
import '../contracts/Wizards.sol';
//import "../contracts/libraries/PRBMathSD59x18Typed.sol";


// todo -- we can drop the idea of floors and just have wizards in the tower, since all "floors" are now equal
// todo -- impliment timeToGold ration, a number that will be used to give time boosts at a cost

contract WizardTower is ReentrancyGuard, Ownable {
    IERC20 public token; // Address of token contract and same used for rewards
    Wizards public wizardsNFT;

    uint128 public totalPowerSnapshot;
    uint40 public totalPowerSnapshotTimestamp;
    uint40 public lastRewardTimestamp;
//    address public evictionProceedsReceiver; // Address to manage the Stake

//    enum Wizards.ELEMENT {FIRE, WIND, WATER, EARTH}


//    struct ContractSettings {
//        uint64 dustThreshold; // min ecosystem tokens to do certain actions like auto withdraw
//        address evictionProceedsReceiver; // Address to manage the Stake
//        address evictor; // Address to manage the Stake
//        uint40 startTimestamp;
//        uint16 activeFloors;
//        uint16 floorCap;
//    }

    struct ContractSettings {
        uint64 dustThreshold; // min ecosystem tokens to do certain actions like auto withdraw
        address evictionProceedsReceiver; // Address to manage the Stake
        address evictor; // Address to manage the Stake
        uint40 startTimestamp;
        uint40 lastUpdatedTimestamp;
        uint32 rewardReleasePeriod;
        uint16 activeFloors;
        uint16 floorCap;
    }

    ContractSettings public contractSettings;


    struct FloorInfo {
        uint40 lastWithdrawalTimestamp;
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
    event NewEvictor(address evictor);

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

    // todo -- require valid floor
    function floorBalance(uint256 _wizardId) public view returns(uint256) {
        if (_wizardId==0 || _wizardId > contractSettings.activeFloors){
            return 0;
        }
        return _floorBalance(_wizardId);
    }

    function _floorBalance(uint256 _wizardId) internal view returns(uint256) {
        uint256 _totalFloorPower = totalFloorPower();
//        return  _totalFloorPower == 0 ? 0 : floorPower(_wizardId) * token.balanceOf((address(this))) / _totalFloorPower;
        uint256 affectivePower =  _totalFloorPower == 0 ? 0 : floorPower(_wizardId) *netAvailableBalance() / _totalFloorPower;
        return affectivePower;
    }

    //////////////
    ////  Core  //
    //////////////

    constructor(address _token, address _wizardsNFTAddress)
    {

        token = IERC20(_token);
        wizardsNFT = Wizards(_wizardsNFTAddress);
//        totalPowerSnapshotTimestamp = uint40(block.timestamp);
        lastRewardTimestamp = uint40(block.timestamp);

        // todo -- make one call
        contractSettings.evictionProceedsReceiver = msg.sender;
        contractSettings.evictor = msg.sender;
//        contractSettings.startTimestamp = totalPowerSnapshotTimestamp;
        contractSettings.floorCap = 10000;
        contractSettings.dustThreshold = uint64(10**16);
//        contractSettings.lastUpdatedTimestamp = totalPowerSnapshotTimestamp; // todo -- this may be duplicate of totalPowerSnapshot
        contractSettings.rewardReleasePeriod = 30 days;
    }

    // For migration
    function drainTower() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(msg.sender, balance), "Unable to transfer token back to the account");
        emit DrainTower(msg.sender, balance);
    }

    // todo -- can make single call to wizardsNFT by making a function or modifier towerReady
    // claim floor for wizard. Returns floor on.
    function claimFloor(uint256 _wizardId) external {
        require(wizardsNFT.isMature(_wizardId)
                && wizardsNFT.ownerOf(_wizardId)==msg.sender
                && wizardsNFT.isActive(_wizardId)
            , "must own mature, active wizardsNFT");
        require(wizardIdToFloorInfo[_wizardId].lastWithdrawalTimestamp == 0, "already claimed");
        require(contractSettings.activeFloors < contractSettings.floorCap, "tower at max capacity");

        // reset snapshot if initiating tower. Otherwise, update it
        if(contractSettings.activeFloors==0){
            totalPowerSnapshot = 0;
            totalPowerSnapshotTimestamp = uint40(block.timestamp);
        }
        else{
            _updateTotalPowerSnapshot(0);
        }

        // increase floors after snapshot
        contractSettings.activeFloors += 1;
        wizardIdToFloorInfo[_wizardId].lastWithdrawalTimestamp = uint40(block.timestamp);

        emit FloorClaimed(msg.sender, _wizardId);
    }


    function evict(uint256 _wizardId) external onlyEvictor {
        require(isOnTheTower(_wizardId), "not on tower");
        uint256 bal = _floorBalance(_wizardId);
//        uint256 myPower = floorPower(_wizardId);

        if (bal > contractSettings.dustThreshold) {
            // numbers adjusted in _withdraw before sending payments
            _withdraw(_wizardId, contractSettings.evictionProceedsReceiver);
        }
        else {
            // dust will be absorbed by all other users
            _updateTotalPowerSnapshot(floorPower(_wizardId));
        }

        delete wizardIdToFloorInfo[_wizardId];

        contractSettings.activeFloors -= 1;
        emit WizardEvicted(_wizardId);
    }



    // todo -- this function doesn't work. We need renewing balances, not a one-time graduation
    /**
     * @notice Calculates the net available balance for distribution across all wizards.
     * @dev The reward is calculated proportionally based on the time elapsed with respect to the rewardReleasePeriod.
     * If the elapsed time is less than the rewardReleasePeriod, a fraction of the total reward is returned.
     * If the elapsed time is greater than or equal to the rewardReleasePeriod, the full balance of the contract is returned.
     * @return The total available balance for distribution.
     */
    function netAvailableBalance() public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastRewardTimestamp;

        if (timeElapsed >= contractSettings.rewardReleasePeriod) {
            return token.balanceOf(address(this));
        } else {
            return timeElapsed * token.balanceOf(address(this)) / contractSettings.rewardReleasePeriod;
        }
    }


    function floorPower(uint256 _wizardId) public view returns(uint128) {
        if(!isOnTheTower(_wizardId)){
            return 0;
        }
//        require(isOnTheTower(_wizardId)); // floor is same as wizardId
        FloorInfo memory floorInfo = wizardIdToFloorInfo[_wizardId]; // wizard id is same as floor id
//        require(floorInfo.lastWithdrawalTimestamp != 0, "ERROR -- THIS SHOULD NOT HAPPEN"); // todo -- remove this and startTimestamp
//        uint256 timestamp = floorInfo.lastWithdrawalTimestamp == 0 ? contractSettings.startTimestamp : floorInfo.lastWithdrawalTimestamp; // todo -- lastWithdrawalTimeStamp should never be 0
        uint256 timestamp = floorInfo.lastWithdrawalTimestamp;

        return uint128(block.timestamp - timestamp);
    }

    function totalFloorPower() public view returns(uint128) {
        return uint128(totalPowerSnapshot + (block.timestamp - totalPowerSnapshotTimestamp) * contractSettings.activeFloors);
    }

    // called when adding/removing floors or withdrawing
    // todo -- make clearer name or break into two functions, reduce; update
    function _updateTotalPowerSnapshot(uint128 _powerRemoved) internal  {
        totalPowerSnapshot = uint128(totalFloorPower() - _powerRemoved);
        totalPowerSnapshotTimestamp = uint40(block.timestamp);
    }

    function withdraw(uint256 _wizardId) external nonReentrant {
        // require owner owns wizardsNFT on that floor
        require(wizardsNFT.ownerOf(_wizardId) == tx.origin, "You do not own the wizard there."); // todo -- confirm tx.origin is ok
        _withdraw(_wizardId, tx.origin);
    }

    function _withdraw(uint256 wizardId, address recipient) internal {
        require(isOnTheTower(wizardId)); // floor is same as wizardId
        uint256 amountToWithdraw = _floorBalance(wizardId);
        require(amountToWithdraw!=0, "nothing to withdraw");
        uint128 myPower = floorPower(wizardId);
        // Check for balance in the contract
        require(token.balanceOf(address(this)) >= amountToWithdraw, "Not enough balance in the contract");

        // Update timestamp
        wizardIdToFloorInfo[wizardId].lastWithdrawalTimestamp = uint40(block.timestamp);

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


   /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _evictor new address for culler, the wallet/contract which can evict wizards from the tower
      */
    function updateEvictor(address _evictor) external onlyOwner {
        require(_evictor != address(0) && _evictor != contractSettings.evictor); // dev: "Invalid operator address"
        contractSettings.evictor = _evictor;
        emit NewEvictor(_evictor);
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


    /// @dev Ensures that the caller is the evictor.
    modifier onlyEvictor() {
        require(msg.sender == contractSettings.evictor, "only evictor");
        _;
    }



}