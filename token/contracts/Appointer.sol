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
    mapping(uint256 => mapping(uint256 => bool)) public canAppoint;


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
        require(isValidRole(_role), "Role does not exist or is not activated.");


        // and have no role (role == 0) or have authority over role
        uint256 appointerRole = wizardContract.getRole(_appointerId);
        require(canAppoint[appointerRole][_role], "No permission to appoint this role.");

        // appoint role
        wizardContract.appointRole(_appointeeId, _role);
    }

    /// @notice Removes the role of a specified wizard.
    /// @dev The calling address must own the appointer wizard and have authority over the appointee's role.
    /// @param _appointerId The ID of the wizard making the removal.
    /// @param _appointeeId The ID of the wizard whose role is being removed.
    function remove(uint256 _appointerId, uint256 _appointeeId) external {
        // msg.sender must own _appointerId
        require(wizardContract.ownerOf(_appointerId) == msg.sender);

        // and have no role (role == 0)
        require(wizardContract.getRole(_appointeeId) != 0, "already removed.");

        uint256 appointerRole = wizardContract.getRole(_appointerId);
        uint256 appointeeRole = wizardContract.getRole(_appointeeId);

        // can remove if removing self or has authority over role
        require(
            _appointerId == _appointeeId || canAppoint[appointerRole][appointeeRole],
            "No permission to remove this role."
        );

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


    /// @notice Sets the activation status of a specific role.
    /// @dev This function can be called by the contract owner or a role with the appropriate authority.
    /// @param _roleId The ID of the role to be set.
    /// @param _status The activation status (true for active, false for inactive).
    function setRoleActivated(uint256 _appointerRole, uint256 _role, bool _status) external {
        require(_roleId <= numRoles && _roleId != 0, "non-existant role");

        // Check if the msg.sender is the owner or has authority over the role.
        require(canAppoint[_appointerRole][_role], "No permission to appoint this role.");

        // Set the role's activation status.
        roles[_roleId].valid = _status;
    }

    /**
     * @dev Checks if a given role ID is valid and currently activated.
     * @param _roleId The ID of the role to check.
     * @return A boolean indicating if the role is valid and activated.
     */
    function isValidRole(uint256 _roleId) public view returns (bool) {
        return _roleId > 0 && _roleId <= numRoles && roles[_roleId].valid;
    }


    ////////////////////////////////
    ////// Modifiers           /////
    ////////////////////////////////

    modifier isWizardOwner(uint256 wizardId) {
        require(wizardContract.ownerOf(wizardId) == msg.sender, "Not the owner of the specified wizard.");
        _;
    }

    modifier roleExists(uint256 roleId) {
        require(roleId > 0 && roleId <= numRoles, "Role does not exist.");
        _;
    }

    modifier canAppointRole(uint256 appointerId, uint256 targetRole) {
        uint256 appointerRole = wizardContract.getRole(appointerId);
        require(appointerRole == 0 || canAppoint[appointerRole][targetRole], "No permission to appoint this role.");
        _;
    }


}
