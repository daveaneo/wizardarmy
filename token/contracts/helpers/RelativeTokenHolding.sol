pragma solidity ^0.8.4;
// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.8.0;

import './Ownable.sol';
import './ReentrancyGuard.sol';
import '../interfaces/IERC20.sol';

contract RelativeTokenHolding is ReentrancyGuard {
    IERC20 public token; // Address of token contract and same used for rewards

    uint256 private constant _MAXTOTALSMALLESTUNIT = (10**12) * (10**18); // total supply * (10**decimals) // todo -- update
    uint256 private constant _BIGBASE = (type(uint256).max - (type(uint256).max % _MAXTOTALSMALLESTUNIT)) / _MAXTOTALSMALLESTUNIT;
    uint256 public constant INITIALLOCKAMOUNT =  10000; // 10** 4; // amount to add during constructor. Preserves relative values and helps tracks total yield
    uint256 public dustThreshold = 10**6; // for getting stakers
    uint256 public totalRelativeStaking = 0;

    address public tokenOperator; // Address to manage the Stake
// impliment these on HOA side
//    address public DAOAddress; // Address to manage the Stake
//    address public ; // Address to manage the Stake

    mapping (address => uint256) public rBalances; // Relative user Token balance in the contract

    address[] stakeHolders;


    // Events
    event NewOperator(address tokenOperator);
    event WithdrawToken(address indexed tokenOperator, uint256 amount);
    event Deposit(address indexed staker, uint256 stakeAmount);
    event Withdraw(address indexed staker, uint256 totalAmount);

    // Modifiers
    modifier onlyOperator() {
        require(
            msg.sender == tokenOperator,
            "Only operator can call this function."
        );
        _;
    }

    constructor(address _token)
    {
        token = IERC20(_token);
        tokenOperator = msg.sender;
    }

    // todo -- DAO Wallet, HOA Wallet, et cetera -- leave to do on main contract?
    // todo -- this initial amount needs to be locked in. Ie, not storing other tokens here
    function loadInitialLockedAmount() external {
        require(rBalances[address(this)] < INITIALLOCKAMOUNT * _BIGBASE); // can only initialize when below constraint
        require(token.transferFrom(msg.sender, address(this), INITIALLOCKAMOUNT), "Token transfer failed.");
        rBalances[address(this)] = INITIALLOCKAMOUNT * _BIGBASE;
        totalRelativeStaking = INITIALLOCKAMOUNT *_BIGBASE;
    }

    function updateOperator(address newOperator) external { // todo -- add in onlyOwner functionality

        require(newOperator != address(0), "Invalid operator address");
        tokenOperator = newOperator;
        emit NewOperator(newOperator);
    }

//    // This would potentially destroy contract.
//    function withdrawInitialLockAmount() external onlyOperator
//    {
//
//    }

        // To set the dust threshold for adding bonus
    function setDustThreshold(uint256 _dustThreshold) external { // todo -- add in onlyOwner functionality
        dustThreshold = _dustThreshold;
    }

    function getBalanceOf(address _addy) public view returns(uint256) {
        return _myBalance(_addy);
    }

    function myBalance() external view returns(uint256) {
        return _myBalance(msg.sender);
    }

    function _myBalance(address _addy) internal view returns(uint256) {
        return rBalances[_addy] * getBalanceOf(_addy) / totalRelativeStaking;
    }


    // todo -- msg.sender or _sender
    // To submit a new stake for the current window
    function deposit(uint256 stakeAmount, address _sender) external {

        // todo -- is address(this) a separate contract???
        uint256 old_total_balance = token.balanceOf(address(this));

        // Transfer the Tokens to Contract
        require(token.transferFrom(msg.sender, address(this), stakeAmount), "Unable to transfer token to the contract");

        // Update the User balance
        rBalances[msg.sender] += totalRelativeStaking * stakeAmount / old_total_balance;
        totalRelativeStaking += totalRelativeStaking * stakeAmount / old_total_balance;

        // add to vault
        _addToVault(stakeAmount);

        emit Deposit(msg.sender, stakeAmount);

    }

    function withdraw() external nonReentrant{

        uint256 stakeAmount;

        stakeAmount = _myBalance(msg.sender);

        // update relative total
        totalRelativeStaking -= rBalances[msg.sender];

        // _withdrawFromVault
        _withdrawFromVault(stakeAmount);

        // Check for balance in the contract
        require(token.balanceOf(address(this)) >= stakeAmount, "Not enough balance in the contract");

        // Update the User Balance
        rBalances[msg.sender] = 0;

        // Call the transfer function
        require(token.transfer(msg.sender, stakeAmount), "Unable to transfer token back to the account");

        emit Withdraw(msg.sender, stakeAmount);
    }


    function _addToVault(uint256 _amount) virtual internal {
        // todo -- rewrite this to add funds to any vault, LP, etc.
        // if no external vault, no need to do anything
    }

    function _withdrawFromVault(uint256 amount) virtual internal {
        // todo -- rewrite this to remove funds to any vault, LP, etc.
        // if no external vault, no need to do anything
    }

    function totalVaultBalance() virtual public returns (uint256){
        return token.balanceOf(address(this));
    }


    // Getter Functions
    function getStakeHolders() external view returns(address[] memory) {
        return stakeHolders;
    }

    function getStakeHoldersAboveDustThreshold() external view returns(address[] memory) {
        address[] memory nonDustHolders;
        uint256 count;
        uint256 counter;

        for(uint256 i=0;i<stakeHolders.length;i++){
            if(_myBalance(stakeHolders[i]) > dustThreshold){
                count += 1;
            }
        }

        nonDustHolders = new address[](count);

        for(uint256 i=0;i<stakeHolders.length;i++){
            if(_myBalance(stakeHolders[i]) > dustThreshold){
                nonDustHolders[counter] = stakeHolders[i];
                counter +=1;
            }
        }

        return nonDustHolders;
    }
}