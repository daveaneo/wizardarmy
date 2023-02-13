pragma solidity 0.8.15;
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
    uint256 ELEMENTSYNERGYMULTIPLIER = 100; // out of 100 (110 means 10% bonus)

    constructor(address _ecosystemToken, address _wizardNFT, address _wizardTower) {
        ecosystemToken = IERC20(_ecosystemToken);
        wizardNFT = Wizards(_wizardNFT);
        wizardTower = WizardTower(_wizardTower);
    }

//    enum Wizards.OUTCOME {LOSS, WIN, TIE, CAPTURE}
//    enum ELEMENT {FIRE, WIND, WATER, EARTH}

    event Attack(uint256 attackerId, uint256 defenderId, uint256 floorAttacked,
                 uint256 netTokensGainedOrLost, Wizards.OUTCOME outcome, uint256 timestamp);
    event Capture(uint256 captured, uint256 capturer, uint256 timestamp);
    event AttackRound(uint256 round, uint256 damageDealt, uint256 defenderHP);

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
        require(_floor != attackingFromFloor, "Can not attack yourself.");

        // 10% fee for attacking
        require(ethValueOfTokensOnFloor*attackFee/10000 <= msg.value, "insuffcient tokens to attack"); // only if other user is valid

        bool _success = false;
        // send extra back
        if((msg.value - ethValueOfTokensOnFloor*attackFee/10000) > dustThreshold){
            (_success, ) = msg.sender.call{value: msg.value - ethValueOfTokensOnFloor*attackFee/10000}("");
        }

        // send Eth to defender
        (_success, ) = wizardNFT.ownerOf(occupyingWizard).call{value: ethValueOfTokensOnFloor*attackFee*(10000 - DAOShare)/(10**8)}("");

        // capture other wizard if they are not active
        Wizards.OUTCOME outcome; // 0 => loss, 1 => win, 2 => tie?, 3 => capture
        if(!wizardNFT.isActive(occupyingWizard)){
            outcome = Wizards.OUTCOME.CAPTURE;
            // handle capture below
        }
        else {
            // todo -- randomness, battle dynamics
//            outcome = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp, block.difficulty, _floor))) % 2;
            outcome = battle(_attackerId, occupyingWizard);
        }

        if(outcome==Wizards.OUTCOME.WIN || outcome==Wizards.OUTCOME.CAPTURE) {
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
           // update NFT stats for wins/loses/tokens
        }
        else { // if loss or tie
            // nothing else to do
        }

        if(outcome==Wizards.OUTCOME.CAPTURE){
            // kick wizard off tower
            wizardTower.captureFloor(attackingFromFloor); // wizard now resides on other floor
            emit Capture(occupyingWizard,_attackerId, block.timestamp);

        }

        wizardNFT.reportBattle(_attackerId, occupyingWizard, outcome, tokensOnFloor, msg.value);

        uint256 tokensWonOrLost = (outcome == Wizards.OUTCOME.WIN) || ( outcome== Wizards.OUTCOME.CAPTURE ) ?  tokensOnFloor*(10000 - attackFee)/10000 : ethValueOfTokensOnFloor*attackFee/10000;
        emit Attack(_attackerId, occupyingWizard, _floor, tokensWonOrLost, outcome, block.timestamp);
    }

    // todo -- return a number between 0 and 200 for all combinations
    function getElementMultiplier(Wizards.ELEMENT attackingElement, Wizards.ELEMENT defendingElement) internal pure returns(uint256){
        // ELEMENTSYNERGYMULTIPLIER
        return 100;
    }

    // @dev find the outcome of _attackerId attacking
    function battle(uint256 _attackerId, uint256 _defenderId) public returns(Wizards.OUTCOME){ // todo -- expose this to public for use in other dApps?
        WizardTower.FloorInfo memory floor = wizardTower.getFloorInfoGivenWizard(_defenderId); // does not contain floor #!
        Wizards.ELEMENT floorElement = floor.element;
        Wizards.Stats[2] memory characters = [wizardNFT.getStatsGivenId(_attackerId), wizardNFT.getStatsGivenId(_defenderId)];

        // todo -- convert this to arrays
//        Wizards.Stats memory attacker = wizardNFT.getStatsGivenId(_attackerId);
//        Wizards.Stats memory defender = wizardNFT.getStatsGivenId(_defenderId);

        uint256 pseudoRandNum = uint256(keccak256(abi.encodePacked(msg.sender, block.timestamp,
            _attackerId, floor.lastWithdrawalTimestamp)));


        // determine who fights first
        uint256 firstToAttack; // 0 means attacker (aggressor)
        uint256 firstAttackSelector = pseudoRandNum % (characters[0].speed + characters[1].speed);
        pseudoRandNum >>= 8; // shift 8 bits
        if(firstAttackSelector > characters[0].speed) {
            firstToAttack = 1; // defender
        }

        // determine buffs ( out of 10**4 )
        uint256[2] memory attackMultipliers =
              [uint256((characters[0].element==floorElement ? ELEMENTSYNERGYMULTIPLIER : 100) * getElementMultiplier(characters[0].element, characters[1].element)),
               uint256((characters[1].element==floorElement ? ELEMENTSYNERGYMULTIPLIER : 100) * getElementMultiplier(characters[1].element, characters[0].element))];

        uint256 attackAmount;
        uint256 attackLuck;
        uint256 defenderIndex; // todo -- battle is only creating losses
        defenderIndex = (firstToAttack==0 ? 1 : 0);
        for(uint256 i=0; i < 20; ){
            attackLuck = uint256(uint8(pseudoRandNum));
            attackLuck = attackLuck > 12 ? attackLuck : 0; // 12/256 likelihood of being 0
//            defenderIndex = (firstToAttack==0 ? 1 : 0);
            // get attack value semi randomly
            attackAmount = attackLuck == 0 ? 0 : characters[firstToAttack].magicalPower*attackMultipliers[firstToAttack] * (192 + attackLuck/4 ) / 256 / 10**4; // 3/4 max hit + 1/4 is random
            // reduce attack amount by defense amount
            attackAmount = attackAmount > characters[defenderIndex].magicalDefense/2 ? attackAmount - characters[defenderIndex].magicalDefense/2 : 0;
            characters[defenderIndex].hp = attackAmount > characters[defenderIndex].hp ? 0 : characters[defenderIndex].hp - attackAmount;


            emit AttackRound(i, attackAmount, characters[defenderIndex].hp);

            if(characters[defenderIndex].hp == 0) {break;}

            unchecked{
                (firstToAttack, defenderIndex) = (defenderIndex, firstToAttack);
                i++;
            }
        }

        if(characters[0].hp == 0 ) {
            return Wizards.OUTCOME.LOSS; // 0
        }
        else if(characters[1].hp == 0 ) {
            return Wizards.OUTCOME.WIN; // 1
        }
        else {
            return Wizards.OUTCOME.TIE; // 2
        }

        // 10 rounds of fight or death

        // report battle outcome


    }

    ////////////////////
    ////    Admin     //
    ////////////////////
    function withdraw() external onlyOwner {
        uint256 tokens = wizardNFT.balanceOf(address(this));
        require(ecosystemToken.transfer(msg.sender,tokens), "transfer failed"); // only if other user is valid
    }



}
