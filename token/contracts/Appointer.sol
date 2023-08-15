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
        bytes32 name; // todo use bytes32, forcing limitations on name size
        uint16[12] rolesCanAppoint;
        bool valid;
    }
    mapping (uint256 => Role) public roles;
    uint256 public numRoles;

    /// @notice Creates a new Appointer contract instance.
    /// @param _wizardContract The address of the associated Wizard contract.
    constructor(address _wizardContract){
        wizardContract = IERC721Wizard(_wizardContract);
    }


    ///////////////////////////////
    ////// Get Functions      /////
    ///////////////////////////////

    /// @notice Fetches the details of a specific role.
    /// @param _role The ID of the role to fetch.
    /// @return Returns the details of the role.    function getRole(uint256 _role) external view returns(Role memory) {
    function getRoleInfo(uint256 _role) external view returns(Role memory) {
        require(_role <= numRoles && _role != 0, "non-existant role");
        return roles[_role];
    }

    ////////////////////////////////
    ////// Core Functions      /////
    ////////////////////////////////

    /// @notice Allows a wizard to appoint another wizard to a specified role.
    /// @param _appointerId The ID of the wizard making the appointment.
    /// @param _appointeeId The ID of the wizard being appointed.
    /// @param _role The role to which the _appointeeId wizard is being appointed.
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

    /// @notice Removes the role of a specified wizard.
    /// @dev The calling address must own the appointer wizard and have authority over the appointee's role.
    /// @param _appointerId The ID of the wizard making the removal.
    /// @param _appointeeId The ID of the wizard whose role is being removed.
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

    /// @notice Creates a new role with the specified attributes.
    /// @dev This function can only be called by the contract owner.
    /// @param _name The name of the new role.
    /// @param _rolesCanAppoint An array representing roles that can appoint this role.
     function createRole(string memory _name, uint8[15] memory _rolesCanAppoint) external onlyOwner {
        Role memory role;
        role.name = _name;
        role.rolesCanAppoint = _rolesCanAppoint;
        numRoles += 1;
        roles[numRoles] = role;
    }
    // pause/unpause role
    // implications? Can't appoint or can't do anything?

    /// @notice Sets the activation status of a specific role.
    /// @dev This function can be called by the contract owner or a role with the appropriate authority.
    /// @param _roleId The ID of the role to be set.
    /// @param _status The activation status (true for active, false for inactive).
    function setRoleActivated(uint256 _roleId, bool _status) external {
        require(_roleId <= numRoles && _roleId != 0, "non-existant role");

        // Check if the msg.sender is the owner or has authority over the role.
        if (msg.sender != owner()) {
            uint256 senderRole = wizardContract.getRole(msg.sender);
            bool hasAuthority = false;

            // Check if sender's role has permission to appoint the role in question.
            for (uint256 i = 0; i < 15; i++) {
                if (roles[senderRole].rolesCanAppoint[i] == _roleId) {
                    hasAuthority = true;
                    break;
                }
            }
            require(hasAuthority, "No authority to set this role's activation status.");
        }

        // Set the role's activation status.
        roles[_roleId].valid = _status;
    }

    // todo whitelist and blacklist?

}
