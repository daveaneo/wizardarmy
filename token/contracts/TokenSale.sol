pragma solidity ^0.8.15;

// SPDX-License-Identifier: MIT
/**
    @title Token Sale Contract
    @dev This contract calculates and processes referral rewards for token sale
 */
import "./Ownable.sol";
// Declare interface to Wizard Token and its required functions that will be used in this contract
interface IERC20WizardToken{
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint256);
}

interface IERC721Wizard{
    function getReferrerId(uint256 _wizardId) external view returns(uint256);
    function getAddressOfWizard(uint256 _wizardId) external view returns(address);
}

contract TokenSale is Ownable{    
    IERC20WizardToken wizardTokenContract;
    IERC721Wizard wizardContract;
    struct coins{
        uint128 purchasedCoins;
        uint128 bonusCoins;
    }
    // referralRewards mapping stores how much unpaid rewards each of the referrer address has earned
    mapping (address => coins) public claimableCoins;
    //This is temp for testing
    mapping (uint256 => uint128) public referralRewardsByWizardId; 
    // uplineReferralPercent mapping stores what is the referral reward % for the upline referrers
    uint16[5] uplineReferralPercent = [20,10,5,3,2];
    uint64 public tokenSalePrice = 100;
    uint128 public totalTokensToBeSold = 10**14;
    uint128 public tokenSoldAmount;
    uint128 public totalRewardsToBeClaimed;
    // Below state variable is used to set if the coins can be claimed by the users or not
    bool public claimPurchasedCoins = false;
    bool public claimRewardsCoins = false;
    
    event TokenSold(address indexed tokenBuyer, uint128 tokenAmount);
    
    constructor(IERC20WizardToken _wizardTokenContract, IERC721Wizard _wizardContract ){
        wizardTokenContract = _wizardTokenContract;
        wizardContract = _wizardContract;                
    }   

    //Token sale price is in wei 
    function setTokenSalePrice(uint64 _tokenSalePrice) public onlyOwner{
        tokenSalePrice = _tokenSalePrice;
    }

    function setClaimPurchasedCoins(bool _status) public onlyOwner{
        claimPurchasedCoins = _status;
    }
    
    function setClaimRewardsCoins(bool _status) public onlyOwner{
        claimRewardsCoins = _status;
    }

    function stopTokenSale() public onlyOwner{
        //transfer unsold tokens to the owner of the contract
        wizardTokenContract.transfer(msg.sender, wizardTokenContract.balanceOf(address(this)));            
        // transfer collected ethers to the owner of the contract
        payable (msg.sender).transfer(address(this).balance);
    }

    function buyToken(uint128 _buyAmountToken, uint256 _wizardId) external payable{
        require (uint128(msg.value) == _buyAmountToken * uint128(tokenSalePrice),"Price paid is incorrect. Hence reverting the TX.");
        uint128 scaledTokenAmount = _buyAmountToken * (uint128(10) ** uint128(wizardTokenContract.decimals()));
        require ((scaledTokenAmount + tokenSoldAmount) <= totalTokensToBeSold,"Not enough tokens left for sale.");
        claimableCoins[msg.sender].purchasedCoins += scaledTokenAmount;
        tokenSoldAmount += scaledTokenAmount;
        emit TokenSold(msg.sender,scaledTokenAmount);
        if (_wizardId > 0){
            _rewardsProcessing(_wizardId, scaledTokenAmount); 
        }                
    }

    function _rewardsProcessing(uint256 _wizardId, uint128 _scaledBuyAmountCoin) private{
        uint256 referrerWizardId = wizardContract.getReferrerId(_wizardId);
        uint128 referralAmount;
        address referrerAddress;
        
        for (uint8 levelCounter=0 ; levelCounter < 5 && referrerWizardId != 0 ; levelCounter++){
            referralAmount = _scaledBuyAmountCoin * uint128(uplineReferralPercent[levelCounter]) / uint128(100);
            referrerAddress = wizardContract.getAddressOfWizard(referrerWizardId);
            referralRewardsByWizardId[referrerWizardId] += referralAmount;
            claimableCoins[referrerAddress].bonusCoins += referralAmount;
            totalRewardsToBeClaimed += referralAmount;
            referrerWizardId = wizardContract.getReferrerId(referrerWizardId);
        }        
    }  

    // If parameter "_purchasedOrRewards" value is "true" then it processes purchased coins claim,
    // if "false", then process rewards coins claim
    function claimCoins(bool _purchasedOrRewards) public{
        if (_purchasedOrRewards == true){
            require(claimPurchasedCoins == true,"Claiming of purchased coins is disabled.");
            require(claimableCoins[msg.sender].purchasedCoins>0,"You do not have any coins to claim.");
            require (wizardTokenContract.balanceOf(address(this)) >= 
            claimableCoins[msg.sender].purchasedCoins);
            require(wizardTokenContract.transfer(msg.sender, claimableCoins[msg.sender].purchasedCoins));
            claimableCoins[msg.sender].purchasedCoins = 0;
        }else{
            require(claimRewardsCoins == true,"Claiming of rewards coins is disabled.");
            require(claimableCoins[msg.sender].bonusCoins>0,"You do not have any coins to claim.");
            require (wizardTokenContract.balanceOf(address(this)) >= 
            claimableCoins[msg.sender].bonusCoins);
            require(wizardTokenContract.transfer(msg.sender, claimableCoins[msg.sender].bonusCoins));
            claimableCoins[msg.sender].bonusCoins = 0;
            totalRewardsToBeClaimed -= claimableCoins[msg.sender].bonusCoins;
        }
    }
}