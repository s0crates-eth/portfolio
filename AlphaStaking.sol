// SPDX-License-Identifier: GNU
pragma solidity ^0.8.9;

/* -.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-. */
/* -.-.-.-.- $CHADGPT ALPHA STAKING POOL v0.2 .-.-.-.-. */
/* -.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-. */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract alphaStaking is ERC20, Ownable{

    IERC20 public tokenAddr; // 0x6632d8c49234a6783b45cdc5fc9355a47124e187 (ChadGPT)

    uint256 public timerDuration; // 248400 (69 hours)
    uint256 public rwdRate; // 420 (4.2% of pool)
    uint256 public stakedPoolSupply;
    bool public stakingOpen;

    mapping(address => bool) public isStaked;
    mapping(address => uint256) public withdrawTimer;
    mapping(address => uint256) public stakedPoolBalances;

    event DepositEmit(address user, uint256 amountDeposited, uint256 userBalance);
    event WithdrawEmit(address user, uint256 userBalance);
    event RewardsEmit(address user, uint256 userBalance, uint256 userReward);

    constructor(
        address _tokenAddr, 
        uint256 _timerDuration, 
        uint256 _rwdRate) 
        ERC20("Alpha Staking", "aChad"){
        tokenAddr = IERC20(_tokenAddr);
        timerDuration = _timerDuration;
        rwdRate = _rwdRate;
        stakingOpen = false;
    }
    
    function calculateRewards(address _user) public view returns (uint256) {
        require(stakingOpen == true, "Staking pool is closed");
        require(isStaked[_user], "This address has not staked");
        uint256 totalTokenBalance = IERC20(tokenAddr).balanceOf(address(this));
        uint256 rwdPoolSupply = totalTokenBalance - stakedPoolSupply;
        uint256 rwdPoolAftrRate = rwdPoolSupply * rwdRate / 10000;
        uint256 userBalance = stakedPoolBalances[_user];
        uint256 userRewardsAmount =  rwdPoolAftrRate * userBalance / stakedPoolSupply;
        return userRewardsAmount;
    }

    function calculateTime(address _user) public view returns (uint256) {
        require(isStaked[_user], "This address has not staked");
        uint256 timeElapsed = block.timestamp - withdrawTimer[_user];
        return timeElapsed;
    }

    function depositToStaking(uint256 _amount) public{
        require(stakingOpen == true, "Staking pool is closed");
        require(_amount > 0, "Deposit must be > 0");
        
        uint before = IERC20(tokenAddr).balanceOf(address(this));
        // all users must APPROVE staking contract to use erc20 before v-this-v can work
        bool success = IERC20(tokenAddr).transferFrom(msg.sender, address(this), _amount);
        require(success == true, "transfer failed!");
        uint totalStaked = (IERC20(tokenAddr).balanceOf(address(this))) - before;
        
        isStaked[msg.sender] = true;
        withdrawTimer[msg.sender] = block.timestamp;
        stakedPoolBalances[msg.sender] += totalStaked;
        stakedPoolSupply += totalStaked;

        _mint(msg.sender, totalStaked); //aChad

        emit DepositEmit(msg.sender, totalStaked, stakedPoolBalances[msg.sender]);
    }

    function withdrawRewards() public{
        require(stakingOpen == true, "Staking pool is closed");
        require(isStaked[msg.sender], "This address has not staked");
        
        uint256 timeElapsed = calculateTime(msg.sender);
        require(timeElapsed >= timerDuration, 'Minimum required staking time not met');

        uint256 userBalance = stakedPoolBalances[msg.sender];
        require(userBalance > 0, 'insufficient balance');

        uint256 userReward = calculateRewards(msg.sender);
        require(userReward > 0, 'insufficient reward');
        
        withdrawTimer[msg.sender] = block.timestamp;
        bool success = IERC20(tokenAddr).transfer(msg.sender, userReward);
        require(success == true, "transfer failed!");

        emit RewardsEmit(msg.sender, userBalance, userReward);
    }

    function withdrawAll() public{
        require(isStaked[msg.sender], "This address has not staked");

        uint256 userBalance = stakedPoolBalances[msg.sender];
        require(userBalance > 0, 'insufficient balance');
        
        uint256 timeElapsed = calculateTime(msg.sender);
        require(timeElapsed < timerDuration, 'withdraw rewards first');

        delete isStaked[msg.sender];
        delete withdrawTimer[msg.sender];
        delete stakedPoolBalances[msg.sender];
        stakedPoolSupply -= userBalance;

        bool success = IERC20(tokenAddr).transfer(msg.sender, userBalance);
        require(success == true, "transfer failed!");

        _burn(msg.sender, userBalance); //aChad

        emit WithdrawEmit(msg.sender, userBalance);
    }

    //onlyOwners
    function setTimer(uint256 _time) external onlyOwner {
        timerDuration = _time;
    }

    function setRate(uint256 _rwdRate) external onlyOwner {
        require(_rwdRate > 0 && _rwdRate < 1000, "Rate must be > 0 and < 1000");
        rwdRate = _rwdRate;
    }

    function setTokenAddress(address _newTokenAddress) external onlyOwner {
        tokenAddr = IERC20(_newTokenAddress);
    } 

    function setStakingOpen(bool _trueOrFalse) external onlyOwner {
        stakingOpen =  _trueOrFalse;
    } 
    
    function closeRewardsPool() external payable onlyOwner {
        uint256 tokenBalance = IERC20(tokenAddr).balanceOf(address(this));
        uint256 gasBalance = address(this).balance;
        if(tokenBalance > 0){
            bool success1 = IERC20(tokenAddr).transfer(msg.sender, tokenBalance - stakedPoolSupply);
            require(success1 == true, "transfer failed!");
        }
        if(gasBalance > 0){
            (bool success2,) = payable(msg.sender).call{value: gasBalance}("");
            require(success2 == true, "transfer failed!");
        }
    }

    // aChad overrides
    function transfer(address to, uint256 amount) public override onlyOwner returns (bool success) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override onlyOwner returns (bool success) {
        return super.transferFrom(from, to, amount);
    }
}
