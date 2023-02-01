/**
 * SPDX-License-Identifier: MIT
 */ 
pragma solidity ^0.8.4;

//import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
//import '@openzeppelin/contracts/math/SafeMath.sol';
import './Whitelist.sol';
import './helpers/Ownable.sol';
//import './Token.sol';
//import '../interfaces/IERC20.sol';
//import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Declare interface to Wizard NFT contract and its required functions that will be used in this contract
interface IERC721Wizard{
    function getUplineId(uint256 _wizardId) external view returns(uint256);
    function getAddressOfWizard(uint256 _wizardId) external view returns(address);
}

contract Crowdsale is Ownable{
    struct Sale {
        uint128 tokenAmount; // purchasedTokens
        uint128 rewards; // rewardedTokens
    }

    struct ContractBoolSettings {
        bool individualCapsTurnedOn;
        bool onlyWhitelisted;
        bool buyersCanWithdrawAdminOverride;
        bool buyersCanWithdrawRewardsAdminOverride;
        bool funded;
        /// more can be added
    }

    ContractBoolSettings contractBoolSettings;
    mapping(address => Sale) public sales;
    IERC20 public token;
    IERC721Wizard wizardContract;
    Whitelist whiteslistContract;

    // todo -- make these variables more memory efficient
    uint256 public end; // Claiming time? Should be different then begin + duration
    uint256 public claimTime; // time stamp in which purchasers can claim tokens
    uint256 public rewardsClaimTime; // time stamp in which referrers can claim their rewards
    uint256 public timeUntilClaiming; // time from start to token claiming
    uint256 public timeUntilRewardsClaiming; // time from start to rewards claiming
    uint256 public duration; // duration of token sale
    uint256 public amountOfMaticForFullToken;
    uint256 public availableTokens; // amount able to be sold
    uint256 public totalTokensOfferedInSale; // starting amount for sale
    uint256 public minPurchase;
    uint256 public maxPurchase;
    uint128 public totalRewardsToBeClaimed;
    uint128 public totalPurchasedTokensToBeClaimed;
    // uplineReferralPercent array stores what is the referral reward % for the upline referrers
    uint16[5] uplineReferralPercent = [20,10,5,3,2];

//    | ----Private Presale ----- || ----------------------- DEAD TIME--------------------- || --- Claiming Period -->
//    | --------DEAD TIME-------- || ----Private Presale ----- || --------DEAD TIME-------- || --- Claiming Period -->
//    | ------------------ DEAD TIME-------------------------- || -------Public Sale------- || --- Claiming Period -->

    constructor(
        address tokenAddress,
        address _wizardContract,
        address _whitelistContractAddress,
        uint256 _duration, //in seconds
        uint256 _timeUntilClaiming, //in seconds, wait time after start
        uint256 _timeUntilRewardsClaiming,
        uint256 _amountOfMaticForFullToken, // corresponding value of Matic that equals 1 full Token ( qty_MATIC / qty_Token )
        uint256 _availableTokens,
        uint256 _minPurchase,
        uint256 _maxPurchase) {
        token = IERC20(tokenAddress);
        wizardContract = IERC721Wizard(_wizardContract);
        
        require(_duration > 0, 'duration should be > 0');
        require( _availableTokens > 0, '_availableTokens should be > 0');
        require(_minPurchase != 0, '_minPurchase should > 0');
        require(_maxPurchase != 0 && _minPurchase <= _maxPurchase && _maxPurchase <= _availableTokens, 'amount error');
        require(_duration <= _timeUntilClaiming && _timeUntilClaiming <= _timeUntilRewardsClaiming, 
        '_duration <= _timeUntilClaiming <= _timeUntilRewardsClaiming');
        whiteslistContract = Whitelist(_whitelistContractAddress);
        duration = _duration;
        amountOfMaticForFullToken = _amountOfMaticForFullToken;
        availableTokens = _availableTokens;
        totalTokensOfferedInSale = _availableTokens;
        minPurchase = _minPurchase;
        maxPurchase = _maxPurchase;
        timeUntilClaiming = _timeUntilClaiming;
        timeUntilRewardsClaiming = _timeUntilRewardsClaiming;

        contractBoolSettings.individualCapsTurnedOn = true;
        contractBoolSettings.onlyWhitelisted = true;
        contractBoolSettings.buyersCanWithdrawAdminOverride = false;
        contractBoolSettings.buyersCanWithdrawRewardsAdminOverride = false;
    }


    //////////////////////////////////////////////////////
    ////// "Public" Get, Non State-Changing Functions /////
    ///////////////////////////////////////////////////////

    function timeUntilClaim() external view returns(uint256){
        return claimTime <= block.timestamp ? 0 : claimTime - block.timestamp;
    }
    
    function timeUntilRewardsClaim() external view returns(uint256){
        return rewardsClaimTime <= block.timestamp ? 0 : rewardsClaimTime - block.timestamp;
    }

    function maticToTokenAmount(uint256 _matic) public view returns(uint256){
        return _matic * 10**9 / amountOfMaticForFullToken;
    }

    function tokenToMaticAmount(uint256 _Token) public view returns(uint256){
        return _Token * amountOfMaticForFullToken / 10**9;
    }

    function getMyAmountOfTokensBought() external view returns(uint256){
        return sales[msg.sender].tokenAmount;
    }


    ///////////////////////////
    ////// Core Functions /////
    ///////////////////////////

    // todo -- remove modifier parantheses
    function start() external onlyOwner icoNotStarted {
        require(contractBoolSettings.funded==true, "Sale not yet funded.");
        end = block.timestamp + duration; // setting "end" to nonzero starts the token sale
        claimTime = block.timestamp + timeUntilClaiming;
        rewardsClaimTime = block.timestamp + timeUntilRewardsClaiming;
        // todo -- test efficiency of "delete"
        delete duration; // reclaim gas
        delete timeUntilClaiming;
        delete timeUntilRewardsClaiming;
    }

    // take into account if previous purchases have happened
    function buy(uint256 _wizardId) public payable icoActive {
        require(contractBoolSettings.onlyWhitelisted == false || whiteslistContract.isWhitelisted(msg.sender), "not whitelisted");
        Sale storage _mySale = sales[msg.sender];
        uint256 tokenAmount = maticToTokenAmount(msg.value);
        require((tokenAmount >= minPurchase) && ((contractBoolSettings.individualCapsTurnedOn==false)
            || (tokenAmount + _mySale.tokenAmount <= maxPurchase)),
            'have to buy between minPurchase and maxPurchase.'
        );
        require(tokenAmount <= availableTokens, 'Not enough tokens left for sale');
        _mySale.tokenAmount += uint128(tokenAmount);
        availableTokens -= tokenAmount;
        totalPurchasedTokensToBeClaimed += uint128(tokenAmount);

        if (_wizardId > 0){
            _rewardsProcessing(_wizardId, tokenAmount); 
        }
    }

    function _rewardsProcessing(uint256 _wizardId, uint256 _buyAmount) private{
        uint256 referrerWizardId = wizardContract.getUplineId(_wizardId);
        uint256 referralAmount;
        address referrerAddress;
        Sale storage _mySale;
        
        for (uint256 levelCounter=0 ; levelCounter < 5 && referrerWizardId != 0 ; levelCounter++){
            referralAmount = _buyAmount * uint256(uplineReferralPercent[levelCounter]) / uint256(100);
            referrerAddress = wizardContract.getAddressOfWizard(referrerWizardId);            
            _mySale = sales[referrerAddress];
            _mySale.rewards += uint128(referralAmount);            
            totalRewardsToBeClaimed += uint128(referralAmount);
            referrerWizardId = wizardContract.getUplineId(referrerWizardId);
        }        
    }  
    
    function withdrawTokens()
        external
        isClaimingPeriod {
        Sale storage sale = sales[msg.sender];
        uint128 purchasedTokenAmount;
        require(sale.tokenAmount > 0, 'No purchased tokens available to claim');
        purchasedTokenAmount = sale.tokenAmount;
        sale.tokenAmount = 0;
        totalPurchasedTokensToBeClaimed -= purchasedTokenAmount;
        require(token.transfer(msg.sender, purchasedTokenAmount));
    }

    // withdrawRewardsTokens function withdraws the rewards
    function withdrawRewardsTokens()
        external
        isClaimingRewardsPeriod {
        Sale storage sale = sales[msg.sender];
        uint128 rewardsAmount;
        require(sale.rewards > 0, 'No rewards to claim');        
        rewardsAmount = sale.rewards;
        sale.rewards = 0;
        totalRewardsToBeClaimed -= rewardsAmount;
        require(token.transfer(msg.sender, rewardsAmount));
    }

    receive() external payable {
        buy(uint256(0));
    }
    ////////////////////////////
    ////// Admin Functions /////
    ////////////////////////////

    // requires approval ???
    function fundTokenSale() external {
        require(contractBoolSettings.funded == false, "already funded.");
//        require(token.transferFrom(admin, address(this), totalTokensOfferedInSale), "Token transfer failed.");
        // approve...
        require(token.transferFrom(msg.sender, address(this), totalTokensOfferedInSale), "Token transfer failed.");
        contractBoolSettings.funded = true;
    }

    function setIndividualCapsTurnedOn(bool _individualCapsTurnedOn) external onlyOwner{
        require(contractBoolSettings.individualCapsTurnedOn != _individualCapsTurnedOn);
        contractBoolSettings.individualCapsTurnedOn = _individualCapsTurnedOn;
    }

    function setOnlyWhitelisted(bool _onlyWhitelisted) external onlyOwner{
        require(contractBoolSettings.onlyWhitelisted != _onlyWhitelisted);
        contractBoolSettings.onlyWhitelisted = _onlyWhitelisted;
    }

    function setBuyersCanWithdrawAdminOverride(bool _buyersCanWithdrawAdminOverride) external onlyOwner{
        require(contractBoolSettings.buyersCanWithdrawAdminOverride != _buyersCanWithdrawAdminOverride);
        contractBoolSettings.buyersCanWithdrawAdminOverride = _buyersCanWithdrawAdminOverride;
    }

    function setBuyersCanWithdrawRewardsAdminOverride(bool _buyersCanWithdrawRewardsAdminOverride) external onlyOwner{
        require(contractBoolSettings.buyersCanWithdrawRewardsAdminOverride != _buyersCanWithdrawRewardsAdminOverride);
        contractBoolSettings.buyersCanWithdrawRewardsAdminOverride = _buyersCanWithdrawRewardsAdminOverride;
    }

    // todo -- add nonrentrant
    function withdrawToken() external onlyOwner icoEnded {
        uint256 _withdrawal = availableTokens;
        availableTokens = 0;
        require(_withdrawal > 0, "No tokens to withdraw that has not been sold.");
        require(token.transfer(owner(), _withdrawal), "Token transfer failed.");
    }

    // todo -- add nonrentrant
    function withdrawMatic() external onlyOwner icoEnded {
        uint256 _balance = address(this).balance;
        require(_balance > 0, "No Matic to withraw.");
        (bool success, ) = owner().call{value : _balance}("Withdrawing Matic to owner");
        require(success, "Transfer failed.");
    }



    //////////////////////
    ////// Modifiers /////
    //////////////////////

    modifier icoActive() {
        require(
          end > 0 && block.timestamp < end && availableTokens > 0 && contractBoolSettings.buyersCanWithdrawAdminOverride == false
          && contractBoolSettings.buyersCanWithdrawRewardsAdminOverride == false,
          'ICO must be active'
        );
        _;
    }
    
    modifier icoNotStarted() {
        require(end == 0, 'ICO has already started');
        _;
    }

    // todo -- make sure this is flush with new logic -- token claim
    modifier icoEnded() {
        require(
          end > 0 && (block.timestamp >= end || availableTokens == 0 ),
          'ICO has ended'
        );
        _;
    }

    modifier isClaimingPeriod() {
        require(
          end > 0 && (block.timestamp >= claimTime
          || contractBoolSettings.buyersCanWithdrawAdminOverride == true),
          'Not time to claim'
        );
        _;
    }

    modifier isClaimingRewardsPeriod() {
        require(
          end > 0 && (block.timestamp >= rewardsClaimTime
          || contractBoolSettings.buyersCanWithdrawRewardsAdminOverride == true),
          'Not time to claim rewards'
        );
        _;
    }
}
