pragma solidity ^0.8.0;
// SPDX-License-Identifier: UNLICENSED

// This will be where wizards receive ecosystem tokens
import "./interfaces/IERC20.sol";
//import "./interfaces/IERC721.sol";
import "./RelativeTimeVault.sol";
import "./WizardTower.sol";
import "./helpers/ReentrancyGuard.sol";
//import "./Wizards.sol";


contract WizardBattle is Ownable, ReentrancyGuard {

    uint256 maxFloors = 10000;
    IERC20 ecosystemToken;
    Wizards wizardNFT;
    WizardTower wizardTower;
    uint256 DAOShare = 300; // out of 10,000 (100%) => 1% // percent of fee
    uint256 attackFee = 1000; // out of 10,000 => 10%
    uint256 dustThreshold =10000;

    constructor(address _ecosystemToken, address _wizardNFT, address _wizardTower) {
        ecosystemToken = IERC20(_ecosystemToken);
        wizardNFT = Wizards(_wizardNFT);
        wizardTower = WizardTower(_wizardTower);
    }

    event Attack(uint256 attackerId, uint256 defenderId, uint256 floorAttacked,
                 uint256 netTokensGainedOrLost, uint256 result, uint256 timestamp);
    event Capture(uint256 captured, uint256 capturer, uint256 timestamp);

    ////////////////////
    ////    Get       //
    ////////////////////


    ////////////////////
    ////    Battle    //
    ////////////////////

    // todo -- decide if use Ether or ERC20 or ERC777
    // todo -- default victory if defender  is not active
//    function attack(uint256 _attackerId, uint256 _floor) external {
//        require(wizardNFT.ownerOf(_attackerId)==msg.sender, "must be NFT holder");
//        require(wizardTower.isOnTheTower(_attackerId), "attacker must be on the tower");
//        require(wizardNFT.isActive(_attackerId), "must be active");
//        require(_floor <= wizardTower.activeFloors() && _floor != 0, "must valid floor");
//        uint256 occupyingWizard = wizardTower.getWizardOnFloor(_floor);
//        uint256 tokensOnFloor = wizardTower.floorBalance(_floor);
//        uint256 tokensWaged = wizardTower.floorBalance(_floor)*attackFee/10000;
//        uint256 attackingFromFloor = wizardTower.wizardIdToFloor(_attackerId);
//
//        // 10% fee for attacking
//        require(ecosystemToken.balanceOf(msg.sender) > tokensWaged, "insuffcient tokens to attack"); // only if other user is valid
//        // send all fees to contract
//        require(ecosystemToken.transferFrom(msg.sender, address(this), tokensWaged), "transfer failed"); // only if other user is valid
//        // send non DAO fees to defenders wallet
//        require(ecosystemToken.transfer(wizardNFT.ownerOf(occupyingWizard), tokensWaged*(10000 - DAOShare)/10000), "transfer failed"); // only if other user is valid
//
//
//        // capture other wizard if they are not active
//        uint256 won; // 0 => loss, 1 => win, 2 => tie?, 3 => capture
//        if(!wizardNFT.isActive(occupyingWizard)){
//            won = 3;
//            // handle capture below
//        }
//        else {
//            // todo -- randomness, battle dynamics
//            won = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty, _floor))) % 2;
//        }
//
//        if(won!=0) {
//            // withdraw tokens before leaving floor
//            if(wizardTower.floorBalance(attackingFromFloor) > dustThreshold) {
//                wizardTower.withdraw(attackingFromFloor);
//            }
//            // switch places
//            wizardTower.switchFloors(attackingFromFloor, _floor);
//            // withdraw tokens at new floor
//            if(wizardTower.floorBalance(_floor) > dustThreshold) {
//                wizardTower.withdraw(_floor);
//            }
//           // update NFT stats for wons/loses/tokens
//        }
//        else {
//            // nothing else to do
//        }
//
//        if(won==3){
//            // kick wizard off tower
//            wizardTower.captureFloor(attackingFromFloor); // wizard now resides on other floor
//            emit Capture(occupyingWizard,_attackerId, block.timestamp);
//
//        }
//
//        wizardNFT.reportBattle(_attackerId, occupyingWizard, won, tokensOnFloor, tokensWaged);
//
//        uint256 tokensWonOrLost = (won == 1) || ( won== 3 ) ?  tokensOnFloor - tokensWaged : tokensWaged;
//        emit Attack(_attackerId, occupyingWizard, _floor, tokensWonOrLost, won, block.timestamp);
//    }
    // use Eth
    // refund extra eth if sent too much
    // todo-- how to deal with tower prices moving up/down?
    // send 15%, get refund if over
    function attack(uint256 _attackerId, uint256 _floor) external payable nonReentrant {
        require(msg.sender == tx.origin, "can not call via contract");
        require(wizardNFT.ownerOf(_attackerId)==msg.sender, "must be NFT holder");
        require(wizardTower.isOnTheTower(_attackerId), "attacker must be on the tower");
        require(wizardNFT.isActive(_attackerId), "must be active");
        require(_floor <= wizardTower.activeFloors() && _floor != 0, "must valid floor");
        uint256 occupyingWizard = wizardTower.getWizardOnFloor(_floor);
        uint256 tokensOnFloor = wizardTower.floorBalance(_floor);
        uint256 ethValueOfTokensOnFloor = 10000; // todo -- use dex to calculate this
//        uint256 tokensWaged = msg.value;
        uint256 attackingFromFloor = wizardTower.wizardIdToFloor(_attackerId);

        // 10% fee for attacking
        require(ethValueOfTokensOnFloor*attackFee/10000 <= msg.value, "insuffcient tokens to attack"); // only if other user is valid

        // send extra back
        if((msg.value - ethValueOfTokensOnFloor*attackFee/10000) > dustThreshold){
            (bool _success, ) = msg.sender.call{value: msg.value - ethValueOfTokensOnFloor*attackFee/10000}("");
        }

        // send Eth to defender
        (bool _success, ) = wizardNFT.ownerOf(occupyingWizard).call{value: ethValueOfTokensOnFloor*attackFee*(10000 - DAOShare)/(10**8)}("");

        // capture other wizard if they are not active
        uint256 won; // 0 => loss, 1 => win, 2 => tie?, 3 => capture
        if(!wizardNFT.isActive(occupyingWizard)){
            won = 3;
            // handle capture below
        }
        else {
            // todo -- randomness, battle dynamics
            won = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty, _floor))) % 2;
        }

        if(won!=0) {
            // withdraw tokens before leaving floor
            if(wizardTower.floorBalance(attackingFromFloor) > dustThreshold) {
                wizardTower.withdraw(attackingFromFloor);
            }
            // switch places
            wizardTower.switchFloors(attackingFromFloor, _floor);
            // withdraw tokens at new floor
            if(wizardTower.floorBalance(_floor) > dustThreshold) {
                wizardTower.withdraw(_floor);
            }
           // update NFT stats for wons/loses/tokens
        }
        else {
            // nothing else to do
        }

        if(won==3){
            // kick wizard off tower
            wizardTower.captureFloor(attackingFromFloor); // wizard now resides on other floor
            emit Capture(occupyingWizard,_attackerId, block.timestamp);

        }

        wizardNFT.reportBattle(_attackerId, occupyingWizard, won, tokensOnFloor, msg.value);

        uint256 tokensWonOrLost = (won == 1) || ( won== 3 ) ?  tokensOnFloor*(10000 - attackFee)/10000 : ethValueOfTokensOnFloor*attackFee/10000;
        emit Attack(_attackerId, occupyingWizard, _floor, tokensWonOrLost, won, block.timestamp);
    }



    ////////////////////
    ////    Admin     //
    ////////////////////
    function withdraw() external onlyOwner {
        uint256 tokens = wizardNFT.balanceOf(address(this));
        require(ecosystemToken.transfer(msg.sender,tokens), "transfer failed"); // only if other user is valid
    }



}
