pragma solidity 0.8.15;
// SPDX-License-Identifier: MIT

interface IERC721Wizard{
    function getUplineId(uint256 _wizardId) external view returns(uint256);
    function ownerOf(uint256 _wizardId) external view returns(address);
    function appointRole(uint256 _wizardId, uint256 _roleId) external;
    function isActive(uint256 _wizardId) external view returns(bool);
    function getRole(uint256 _wizardId) external view returns(uint256);
}

import './helpers/Ownable.sol';

/// @title A contract to manage roles and appointments for Wizards.
/// @notice This contract allows for the creation of roles and the appointment of wizards to those roles.
contract Appointer is Ownable {

    IERC721Wizard wizardContract;
    struct Role {
        bytes32 name;
        bool paused;
        bool canCreateTaskTypes;
        uint16 maxHolders;
        uint16 currentHolders;
    }

    mapping (uint256 => Role) public roles;
    uint256 public numRoles;
    mapping(uint256 => mapping(uint256 => bool)) public canAppoint; // maps role to a mapping of roles they can create tasks for

    event RoleCreated(uint256 roleId, string name, bool paused);
    event RoleAppointed(uint256 wizardId, uint256 roleId);
    event RoleRemoved(uint256 wizardId);
    event RoleActivationChanged(uint256 roleId, bool paused);
    event RoleCanAppointAdded(uint16 role, uint16 canAppointRole);
    event RoleCanAppointRemoved(uint16 role, uint16 canAppointRole);


    /// @notice Creates a new Appointer contract instance.
    /// @param _wizardContract The address of the associated Wizard contract.
    constructor(address _wizardContract){
        wizardContract = IERC721Wizard(_wizardContract);
    }


    ///////////////////////////////
    ////// Get Functions      /////
    ///////////////////////////////

    /// @notice Fetches the details of a specific role.
    /// @param _roleId The ID of the role to fetch.
    /// @return Returns the details of the role.
    function getRoleInfo(uint256 _roleId) external view returns(Role memory) {
        require(_roleId <= numRoles && _roleId != 0, "non-existant role");
        return roles[_roleId];
    }


    /// @notice Determines if role can appoint a delegate over specific role.
    /// @param _appointerRoleId The ID of the role that delegates.
    /// @param _appointeeRoleId The ID of the role that is delegated.
    /// @return Returns true if can delegate given role; false otherwise.
    function canDelegateRole(uint256 _appointerRoleId, uint256 _appointeeRoleId) external view returns(bool) {
        require(_appointerRoleId <= numRoles && _appointerRoleId != 0); // dev: "non-existant role"
        require(_appointeeRoleId <= numRoles && _appointeeRoleId != 0); // dev: "non-existant role"
        return roles[_appointerRoleId].canCreateTaskTypes && canAppoint[_appointerRoleId][_appointeeRoleId];
    }


    /// @notice Determines if role can create TaskTypes
    /// @param _roleId The ID of the role to fetch.
    /// @return Returns true if can appoint; false otherwise.
    function canRoleCreateTasks(uint256 _roleId) external view returns(bool) {
        require(_roleId <= numRoles && _roleId != 0, "non-existant role"); // todo -- roleId 0 is default role, general
        return roles[_roleId].canCreateTaskTypes;
    }


    ////////////////////////////////
    ////// Core Functions      /////
    ////////////////////////////////

    /// @notice Allows a wizard to appoint another wizard to a specified role.
    /// @param _appointerId The ID of the wizard making the appointment.
    /// @param _appointeeId The ID of the wizard being appointed.
    /// @param _roleId The role to which the _appointeeId wizard is being appointed.
    function appoint(uint256 _appointerId, uint256 _appointeeId, uint256 _roleId)
        external
        isWizardOwner(_appointerId)
        roleExists(_roleId)
        canAppointRole(_appointerId, _roleId)
        isActiveWizard(_appointerId) isActiveWizard(_appointeeId)
    {
        _appoint(_appointeeId, _roleId);
    }

    /// @notice Allows admin to appoint another wizard to a specified role.
    /// @param _appointeeId The ID of the wizard being appointed.
    /// @param _roleId The role to which the _appointeeId wizard is being appointed.
    function appointAsAdmin(uint256 _appointeeId, uint256 _roleId)
        external
        onlyOwner
        roleExists(_roleId)
        isActiveWizard(_appointeeId)
    {
        _appoint(_appointeeId, _roleId);
    }

    /// @notice Allows admin to appoint another wizard to a specified role.
    /// @param _appointeeId The ID of the wizard being appointed.
    /// @param _roleId The role to which the _appointeeId wizard is being appointed.
    function _appoint(uint256 _appointeeId, uint256 _roleId)
        internal
    {
        //  and have no role (role==0)
        require(wizardContract.getRole(_appointeeId) == 0, "must have no role.");
        require(roles[_roleId].currentHolders < roles[_roleId].maxHolders, "role maxed out.");

        // appoint role
        wizardContract.appointRole(_appointeeId, _roleId); // todo -- this is causing problems
        roles[_roleId].currentHolders += 1;
    }



    /// @notice Removes the role of a specified wizard.
    /// @dev The calling address must own the appointer wizard and have authority over the appointee's role.
    /// @param _appointerId The ID of the wizard making the removal.
    /// @param _appointeeId The ID of the wizard whose role is being removed.
    function remove(uint256 _appointerId, uint256 _appointeeId)
        external
        isWizardOwner(_appointerId)
        isActiveWizard(_appointerId)
    {
        uint256 appointeeRole = wizardContract.getRole(_appointeeId);
        require(appointeeRole != 0, "already removed.");
        uint256 appointerRole = wizardContract.getRole(_appointerId);

        require(
            _appointerId == _appointeeId || canAppoint[appointerRole][appointeeRole],
            "No permission to remove this role."
        );

        wizardContract.appointRole(_appointeeId, 0);
        roles[appointeeRole].currentHolders -= 1;
        emit RoleRemoved(_appointeeId);
    }

    /// @notice Sets the ability of a role to appoint another role.
    /// @dev This function can only be called by the contract owner.
    /// @param _roleId The ID of the role being modified.
    /// @param _canAppointRoleId The role ID that the role can/cannot appoint.
    /// @param _status True if the role should be able to appoint, false otherwise.
    function setCanAppoint(uint256 _roleId, uint256 _canAppointRoleId, bool _status)
        external
        onlyOwner
        roleExists(_roleId)
        roleExists(_canAppointRoleId)
    {
        require(canAppoint[_roleId][_canAppointRoleId] != _status, "Given role can already appoint this role.");
        canAppoint[_roleId][_canAppointRoleId] = _status;

        if (_status) {
            emit RoleCanAppointAdded(uint16(_roleId), uint16(_canAppointRoleId));
        } else {
            emit RoleCanAppointRemoved(uint16(_roleId), uint16(_canAppointRoleId));
        }
    }


    /// @notice Creates a new role with the specified attributes.
    /// @dev This function can only be called by the contract owner.
    /// @param _name The name of the new role.
    /// @param _rolesCanAppoint An array representing roles that the new role can appoint.

    /// @notice Creates a new role with the specified attributes.
    /// @dev This function can only be called by the contract owner.
    /// @param _name The name of the new role.
    /// @param _rolesCanAppoint An array representing roles that the new role can appoint.
    function createRole(string memory _name, bool _canCreateTaskTypes, uint16 _maxHolders, uint256[] memory _rolesCanAppoint) external onlyOwner {
        // Ensure role name is 32 bytes or less
        bytes memory roleNameBytes = bytes(_name);
        require(roleNameBytes.length <= 32, "Role name too long!");

        // Convert role name string to bytes32
        bytes32 roleNameAsBytes32 = bytes32(uint256(keccak256(roleNameBytes)));

        // Increment the number of roles
        numRoles += 1;

        roles[numRoles] = Role({
            name: roleNameAsBytes32,
            paused: false,   // the default value, can be omitted if you wish
            canCreateTaskTypes : _canCreateTaskTypes,
            maxHolders: _maxHolders,
            currentHolders: 0   // since it's a new role, currentHolders is 0
        });

        // Loop through the roles this role can appoint
        for (uint i = 0; i < _rolesCanAppoint.length; i++) {
            uint256 roleToAppoint = _rolesCanAppoint[i];
            require(roleToAppoint <= numRoles, "Role to appoint does not exist.");
            canAppoint[numRoles][roleToAppoint] = true;
            emit RoleCanAppointAdded(uint16(numRoles), uint16(roleToAppoint));
        }

        // Emit event
        emit RoleCreated(numRoles, _name, false);
    }




    /// @notice Sets the activation status of a specific role.
    /// @dev This function can be called by the contract owner or a role with the appropriate authority.
    /// @param _roleId The ID of the role to be set.
    /// @param _paused The activation status (true for paused, false for not paused).
    function pauseRole(uint256 _appointerRole, uint256 _roleId, bool _paused) external
        roleExists(_roleId)
        canAppointRole(_appointerRole, _roleId)
        {
        // Set the role's activation status.
        roles[_roleId].paused = _paused;
        emit RoleActivationChanged(_roleId, _paused);

    }

    /**
     * @dev Checks if a given role ID is valid and currently activated.
     * @param _roleId The ID of the role to check.
     * @return A boolean indicating if the role is valid and activated.
     */
    function isValidRole(uint256 _roleId) public view returns (bool) {
        return _roleId > 0 && _roleId <= numRoles && !roles[_roleId].paused;
    }


    ////////////////////////////////
    ////// Modifiers           /////
    ////////////////////////////////

    /// @notice Ensures that the caller is the owner of the specified wizard.
    modifier isWizardOwner(uint256 wizardId) {
        require(wizardContract.ownerOf(wizardId) == msg.sender, "Not the owner of the specified wizard.");
        _;
    }

    /// @notice Ensures that the specified role exists.
    modifier roleExists(uint256 roleId) {
        require(roleId > 0 && roleId <= numRoles, "Role does not exist.");
        _;
    }

    /// @notice Checks if the specified wizard has permission to appoint the given role.
    modifier canAppointRole(uint256 appointerId, uint256 targetRole) {
        uint256 appointerRole = wizardContract.getRole(appointerId);
        require(canAppoint[appointerRole][targetRole], "No permission to appoint this role.");
        _;
    }

    /// @notice Ensures that the specified wizard is active.
    modifier isActiveWizard(uint256 wizardId) {
        require(wizardContract.isActive(wizardId), "Wizard is not active.");
        _;
    }



}
