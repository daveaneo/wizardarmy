pragma solidity 0.8.15;
// SPDX-License-Identifier: UNLICENSED

interface IERC721Wizard{
    function getUplineId(uint256 _wizardId) external view returns(uint256);
    function ownerOf(uint256 _wizardId) external view returns(address);
    function appointRole(uint256 _wizardId, uint256 _role) external;
    function isActive(uint256 _wizardId) external view returns(bool);
    function getRole(uint256 _wizardId) external view returns(uint256);
}

import './helpers/Ownable.sol';


contract Appointer is Ownable {

    IERC721Wizard wizardContract;
    struct Role {
        string name; // todo use bytes32, forcing limitations on name size
        uint8[15] rolesCanAppoint;
        bool valid;
    }
    mapping (uint256 => Role) public roles;
    uint256 public numRoles;

    constructor(address _wizardContract){
        wizardContract = IERC721Wizard(_wizardContract);
    }


    ///////////////////////////////
    ////// Get Functions      /////
    ///////////////////////////////

    function getRole(uint256 _role) external view returns(Role memory) {
        require(_role <= numRoles && _role != 0, "non-existant role");
        return roles[_role];
    }

    ////////////////////////////////
    ////// Core Functions      /////
    ////////////////////////////////

    function appoint(uint256 _appointerId, uint256 _appointeeId, uint256 _role) external {
        // msg.sender must own _appointerId
        require(wizardContract.ownerOf(_appointerId)==msg.sender);

        // _appointeeId must exist
        require(wizardContract.isActive(_appointerId) && wizardContract.isActive(_appointeeId), "both must be active.");

        //  and have no role (role==0)
        require(wizardContract.getRole(_appointeeId) == 0, "must have no role.");

        // _appointeeId must have _role in rolesCanAppoint
        uint256 appointerHasPermission = 0;
        uint256 appointerRole = wizardContract.getRole(_appointerId);
        for(uint256 i=0;i<15;){
            if(roles[appointerRole].rolesCanAppoint[i]==_role){
                appointerHasPermission = 1;
                break;
            }
            unchecked{++i;}
        }
        require(appointerHasPermission==1, "no permission.");
        wizardContract.appointRole(_appointeeId, _role);
    }


    function remove(uint256 _appointerId, uint256 _appointeeId) external {
        // msg.sender must own _appointerId
        require(wizardContract.ownerOf(_appointerId)==msg.sender);

        //  and have no role (role==0)
        require(wizardContract.getRole(_appointeeId) != 0, "already removed.");

        // can remove if removing self or has authority over role
        uint256 appointerHasPermission = 0;
        if(_appointerId==_appointeeId){
            appointerHasPermission = 1;
        }
        else{
            uint256 appointerRole = wizardContract.getRole(_appointerId);
            uint256 appointeeRole = wizardContract.getRole(_appointeeId);
            for(uint256 i=0;i<15;){
                if(roles[appointerRole].rolesCanAppoint[i]==appointeeRole){
                    appointerHasPermission = 1;
                    break;
                }
                unchecked{++i;}
            }
        }
        require(appointerHasPermission==1, "no permission.");
        wizardContract.appointRole(_appointeeId, 0);
    }

    function createRole(string memory _name, uint8[15] memory _rolesCanAppoint) external onlyOwner {
        Role memory role;
        role.name = _name;
        role.rolesCanAppoint = _rolesCanAppoint;
        numRoles += 1;
        roles[numRoles] = role;
    }
    // pause/unpause role
    // implications? Can't appoint or can't do anything?

    // todo toggleRoleActivated

    // todo whitelist and blacklist?

}
