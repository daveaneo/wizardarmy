pragma solidity 0.8.15;
// SPDX-License-Identifier: UNLICENSED

// This will be where wizards receive ecosystem tokens
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./RelativeTimeVault.sol";


contract WizardTower is RelativeTimeVault {

    uint256 maxFloors = 10000;
//    IERC20 ecosystemToken;
//    IERC721 wizardToken;

    constructor(address _ecosystemToken, address _wizardToken) RelativeTimeVault(_ecosystemToken, _wizardToken) {
//        ecosystemToken = IERC20(_ecosystemToken);
//        wizardToken = IERC721(_wizardToken);
    }

    ////////////////////
    ////    Get       //
    ////////////////////


    ////////////////////
    ////    Battle    //
    ////////////////////

    function attack(uint256 floor) external { }


    ////////////////////
    ////    Admin     //
    ////////////////////



}
