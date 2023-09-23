// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

//import "./helpers/ERC721.sol";
import "./helpers/Ownable.sol";
import "./helpers/ERC721Enumerable.sol";
import "./libraries/Base64.sol";
import "./libraries/Strings.sol";
import "./libraries/GeneLogic.sol";
import "./libraries/CommonDefinitions.sol";
import "./libraries/SVGGenerator.sol";
import "./libraries/TokenURILibrary.sol";


//import "OpenZeppelin/openzeppelin-contracts@4.6.0/contracts/token/ERC721/ERC721.sol";
//import "estarriolvetch/ERC721Psi/contracts/ERC721Psi.sol";

/// @title Interface for Reputation Contract
/// @dev This interface describes the functions that the reputation contract should implement.
interface IReputationContract {
    function getReputation(uint256 wizardId) external view returns (uint256);
}


contract Wizards is ERC721Enumerable, Ownable {
    mapping (uint256 => CommonDefinitions.WizardStats) public tokenIdToStats;
    address public verifier; /// contract address to update stats
    address public culler; /// contract address to exile any wizard
    address public appointer; /// contract address to assign roles

    IReputationContract public reputationSmartContract;

    struct ContractSettings { // todo refine, update setter
        uint256 mintCost; // Cost in ETH to mint NFT
        uint256 initiationCost; // Cost in ETH to initiate NFT (after minting)
        // cull the herd and reduce to 1000... 400, and so forth? total or per role?
        uint256 maxSupply; // Max supply of NFTs
        uint256 maxActiveWizards; // Max supply of NFTs that can be active
        uint256 protectionTimeExtension; //
        uint256 exileTimePenalty; // time to wait before able to reactivate
        address ecosystemTokenAddress; // address of ecoystem token
        uint256 phaseDuration; // time in seconds for each phase of wizard life
        uint256 totalPhases; // total phases for wizards -- aiming for 8
        uint256 maturityThreshold; // phase in which wizard can enter Wizard Tower
        string imageBaseURI; // base URI where images are stored
        bool wizardSaltSet;
    }

    ContractSettings public contractSettings;

    // Random number for creating wizard genes
    uint256 private wizardSalt;

    event NewVerifier(address verifier);
    event NewCuller(address culler);
    event NewAppointer(address appointer);
    event Initiated(address initiater, uint256 indexed wizardId, uint256 timestamp);
    event Exiled(address exilee, uint256 indexed wizardId, uint256 timestamp);


    ////////////////////
    ////    Get       //
    ////////////////////

    /** @dev Check if wizard is active
      * @param _wizardId id of wizard.
      * @return true if active, false if inactive
      */
    function isActive(uint256 _wizardId) public view returns(bool) {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        return tokenIdToStats[_wizardId].protectedUntilTimestamp > block.timestamp;
    }


    /** @dev check if wizard has been exiled (temporarily banished)
      * @param _wizardId id of wizard.
      * @return true -> exiled; false -> not exiled
      */
    function isExiled(uint256 _wizardId) public view returns(bool) {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        return tokenIdToStats[_wizardId].protectedUntilTimestamp != 0 && tokenIdToStats[_wizardId].initiationTimestamp ==0;
    }

    /** @dev check if wizard has deserted and thus can be exiled
      * @param _wizardId id of wizard.
      * @return true -> deserted; false -> has not deserted
      */
    function hasDeserted(uint256 _wizardId) public view returns(bool) {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        return tokenIdToStats[_wizardId].protectedUntilTimestamp < block.timestamp && tokenIdToStats[_wizardId].initiationTimestamp ==0;
    }


    /** @dev Check if wizard is mature -- can be in wizard tower
      * @param _wizardId id of wizard.
      * @return true if active, false if inactive
      */
    function isMature(uint256 _wizardId) external view returns(bool) {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        return getPhaseOf(_wizardId) >= contractSettings.maturityThreshold;
    }


    /** @dev Get upline of wizard
      * @param _wizardId id of wizard.
      * @return wizardId of upline
      */
    function getUplineId(uint256 _wizardId) external view returns(uint256) {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        return tokenIdToStats[_wizardId].uplineId;
    }

    /** @dev Get role of wizard
      * @param _wizardId id of wizard.
      * @return wizardId of upline
      */
    function getRole(uint256 _wizardId) external view returns(uint256) {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        return tokenIdToStats[_wizardId].role;
    }

    /// @notice A function in Wizards that uses the reputation contract.
    /// @param _wizardId The ID of the wizard whose reputation needs to be fetched.
    /// @return The reputation value of the specified wizard.
    function getReputation(uint256 _wizardId) external view returns (uint256) {
        /// @dev Fetching the reputation from the reputation contract.
        return reputationSmartContract.getReputation(_wizardId);
    }


    /** @dev returns stats of wizard, potentially amplified by level or phase
      * @param _wizardId id of wizard.
      * @return stats
      */
    function getStatsGivenId(uint256 _wizardId) external view returns(CommonDefinitions.WizardStats memory) {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        return tokenIdToStats[_wizardId];
        //todo -- extended stats
    }


    /** @dev Returns phase of wizard
      * @param _wizardId id of wizard.
      * @return number representing phase
      */
    function getPhaseOf(uint256 _wizardId) public view returns(uint256) {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        uint256 phase =
          (block.timestamp - tokenIdToStats[_wizardId].initiationTimestamp) / contractSettings.phaseDuration
          > (contractSettings.totalPhases - 1) ? (contractSettings.totalPhases - 1) : (block.timestamp - tokenIdToStats[_wizardId].initiationTimestamp) / contractSettings.phaseDuration
          ;
        return phase;
    }

    /**
     * @dev Checks if the given wizard ID is valid.
     * A valid wizard ID is non-zero and less than or equal to the total supply of wizards.
     *
     * @param _wizardId The ID of the wizard to be checked.
     * @return True if the wizard ID is valid, otherwise false.
     */
    function _isValidWizard(uint256 _wizardId) internal view returns (bool) {
        return _wizardId != 0 && _wizardId <= totalSupply();
    }


    ///////////////////////////
    ////// Core Functions /////
    ///////////////////////////

    /**
     * @dev initiate Wizards NFT
     * @param _name name of NFT
     * @param _symbol symbol for NFT
     * @param _ERC20Address address for ecosystem token (currency)
     * @param _imageBaseURI base URI used for images
     */
    constructor(string memory _name, string memory _symbol, address _ERC20Address, string memory _imageBaseURI)
        ERC721(_name, _symbol)
    {
        contractSettings = ContractSettings({
            mintCost: 5,
            initiationCost: 10,
            maxSupply: 8192,
            maxActiveWizards: 8192,
            protectionTimeExtension: 1 days,
            exileTimePenalty: 30 days,
            ecosystemTokenAddress: _ERC20Address,
            phaseDuration: 60*60,
            totalPhases: 8,
            maturityThreshold: 0,
            imageBaseURI: _imageBaseURI,
            wizardSaltSet : false
        });

        verifier = msg.sender;
        culler = msg.sender;
        appointer = msg.sender;
    }


    /**
      * @dev check if wizard has deserted and thus can be exiled
      * @param _uplineId id of referring wizard. use 0 if no referral
      */
    function mint(uint16 _uplineId) external {
        require(totalSupply() < contractSettings.maxSupply); // dev: "at max supply."
        require(_uplineId <= totalSupply()); // dev: "invalid upline--must be less than total supply"

        CommonDefinitions.WizardStats memory myStats =  CommonDefinitions.WizardStats(0, _uplineId, 0, 0);
        tokenIdToStats[totalSupply()+1] = myStats;
        _safeMint(msg.sender, totalSupply()+1 ); // with with 1 as id
    }


    /** @dev Changes NFT from uninitated or exiled to initiated
      * @param _wizardId id of wizard.
      */
    function initiate(uint256 _wizardId) external payable {
        require(ownerOf(_wizardId) == msg.sender); // dev: "must be owner"
        require(tokenIdToStats[_wizardId].initiationTimestamp == 0); // dev: "already initiated"
        require(tokenIdToStats[_wizardId].protectedUntilTimestamp + contractSettings.exileTimePenalty <  block.timestamp); // dev: "Exiled wizard not yet allowed to return."
        require(msg.value == contractSettings.initiationCost); // dev: "incorrect initiation fee"

        CommonDefinitions.WizardStats storage myStats = tokenIdToStats[_wizardId];
        myStats.initiationTimestamp = uint40(block.timestamp);
        myStats.protectedUntilTimestamp = uint40(block.timestamp + contractSettings.protectionTimeExtension);

        emit Initiated(msg.sender, _wizardId, block.timestamp);
    }

    /**
     * @dev Resets the statistics of a given wizard by its token ID.
     * The function sets the wizard's statistics back to default values while preserving the upline ID.
     *
     * @param tokenId The ID of the wizard whose statistics are to be reset.
     */
    function _resetWizard(uint256 tokenId) internal {
        // Reset the states
        CommonDefinitions.WizardStats memory myStats = tokenIdToStats[tokenId];
        tokenIdToStats[tokenId] = CommonDefinitions.WizardStats(0, myStats.uplineId, 0, 0);
    }


    /** @dev exile an NFT that is negligent in duties. Use only for culling.
      * @param _wizardId id of wizard.
      */
    function cull(uint256 _wizardId) external onlyCuller {
        _exile(_wizardId);
    }

    /** @dev exile an NFT that is negligent in duties. Any address can call this, but wizard must have deserted
      * @param _wizardId id of wizard.
      */
    function exile(uint256 _wizardId) external {
        require(hasDeserted(_wizardId)); // dev: "wizard can not be exiled."
        _exile(_wizardId);
    }

    /** @dev exile an NFT that is negligent in duties. Never called by address directly, only by cull or exile
      * @param _wizardId id of wizard.
      */
    function _exile(uint256 _wizardId) internal {
        require(_wizardId!=0 && _wizardId <= totalSupply()); // dev: "invalid id"
        require(!isExiled(_wizardId)); // dev: "wiz already in exile"
        tokenIdToStats[_wizardId].protectedUntilTimestamp = uint40(block.timestamp); // this saves the time of exile started
        tokenIdToStats[_wizardId].initiationTimestamp = 0;
    }


    /** @dev get token URI
      * @param _wizardId id of wizard.
      * @return returns inline URI as string
      */
    function tokenURI(uint256 _wizardId) public view virtual override returns (string memory) {
        require(_exists(_wizardId)); // dev: "ERC721Metadata: URI query for nonexistent token"
        // todo -- update image
        string memory imageURI =  TokenURILibrary.getImageURI(_wizardId, wizardSalt, getPhaseOf(_wizardId), contractSettings.totalPhases,
                                           contractSettings.maturityThreshold, contractSettings.imageBaseURI,
                                           tokenIdToStats[_wizardId].initiationTimestamp==0,  isExiled(_wizardId), isActive(_wizardId));


        return TokenURILibrary.formatTokenURI(_wizardId, imageURI, tokenIdToStats[_wizardId], wizardSalt);

    }

    //    todo -- make an actual random number generator with chainlink
    function setRandomNumber(uint256 _wizardSalt) external saltNotSet onlyOwner {
        wizardSalt = _wizardSalt;
        contractSettings.wizardSaltSet = true;
    }


    ///////////////////////////////////
    ////// Verifier Functions     /////
    ///////////////////////////////////

    /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _wizardId id of wizard.
      * @param _timeReward amout of time in seconds to add to current protectedUntilTimestamp
      */
    function increaseProtectedUntilTimestamp(uint256 _wizardId, uint40 _timeReward) external onlyVerifier {
        require(_wizardId!=0 && _wizardId <= totalSupply()); // dev: "invalid id"
        require(tokenIdToStats[_wizardId].initiationTimestamp!=0); // dev: "is not initiated"
        tokenIdToStats[_wizardId].protectedUntilTimestamp += _timeReward;
    }


    ////////////////////////////////////
    ////// Appointer Functions     /////
    ////////////////////////////////////

    function appointRole(uint256 _wizardId, uint16 _role) external onlyAppointer {
        require(_isValidWizard(_wizardId)); // dev: "invalid wizard"
        tokenIdToStats[_wizardId].role = _role;
    }



    ////////////////////////////////////
    ////// Override Functions     /////
    ////////////////////////////////////

    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721, IERC721)  {
        // Call the parent contract's implementation of transferFrom
        super.transferFrom(from, to, tokenId);

        // Reset the states of the wizard after transfer
        _resetWizard(tokenId);
    }

    /////////////////////////////////
    ////// Admin Functions      /////
    /////////////////////////////////


    /** @dev modify contract settings. Only available to owner
      * @param _imageBaseURI baseURI for images
      * @param _phaseDuration period in seconds for phases
      * @param _protectionTimeExtension problby remove this // todo -- delete
      * @param _initiationCost cost in ETH to initiate
      */
    function modifyContractSettings(string memory _imageBaseURI, uint256 _phaseDuration, uint256 _protectionTimeExtension, uint256 _mintCost,
                    uint256 _initiationCost, uint256 _maturityThreshold) external onlyOwner {
        contractSettings.imageBaseURI = _imageBaseURI;
        contractSettings.phaseDuration = _phaseDuration;
        contractSettings.protectionTimeExtension = _protectionTimeExtension;
        contractSettings.mintCost = _mintCost;
        contractSettings.initiationCost = _initiationCost;
        contractSettings.maturityThreshold = _maturityThreshold;
    }


    /// @notice Sets the address of the reputation contract.
    /// @dev Can only be called by the owner of the Wizards contract.
    /// @param _reputationContractAddress The address of the reputation contract.
    function setReputationSmartContract(address _reputationContractAddress) external onlyOwner {
        reputationSmartContract = IReputationContract(_reputationContractAddress);
    }


    ///////////////////////////
    ////// Modifiers      /////
    ///////////////////////////


    /// @dev Ensures that the caller is the verifier.
    modifier onlyVerifier() {
        require(msg.sender == verifier, "only verifier");
        _;
    }

    /// @dev Ensures that the caller is the appointer.
    modifier onlyAppointer() {
        require(msg.sender == appointer, "only appointer");
        _;
    }


    /// @dev Ensures that the caller is the culler.
    modifier onlyCuller() {
        require(msg.sender == culler, "Only culler can call this function.");
        _;
    }

    /// @dev Ensures that the wizard salt has not been set.
    modifier saltNotSet() {
        require(!contractSettings.wizardSaltSet, "Number is already set");
        _;
    }


    ///////////////////////////
    ////// Admin      /////
    ///////////////////////////

    /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _culler new address for culler, the wallet/contract which can exile wizards without contraint
      */
    function updateCuller(address _culler) external onlyOwner {
        require(_culler != address(0) && _culler != culler); // dev: "Invalid operator address"
        culler = _culler;
        emit NewCuller(_culler);
    }

    /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _verifier the new address for verifier, the contract which can add protectedUntil time for wizards
      */
    function updateVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0) && _verifier != verifier); // dev: "Invalid operator address"
        verifier = _verifier;
        emit NewVerifier(_verifier);
    }

    /** @dev increase protectionTimestamp, called by verifier. Used to keep wizard from being exiled.
      * @param _appointer the new address for appointer, the contract which can appoint and create roles
      */
    function updateAppointer(address _appointer) external onlyOwner {
        require(_appointer != address(0) && _appointer != appointer); // dev: "Invalid operator address"
        appointer = _appointer;
        emit NewAppointer(_appointer);
    }

    /**
     * @notice Allows the contract owner to withdraw the accumulated fees.
     * @dev Withdraws all Ether stored in the contract and sends it to the owner.
     * Only callable by the contract owner.
     */
    function withdraw() external onlyOwner {
        address payable recipient = payable(owner());
        recipient.transfer(address(this).balance);
    }


}
