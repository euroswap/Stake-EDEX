// SPDX-License-Identifier: MIT
pragma solidity ^0.6.2;
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
import '@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
import '@pancakeswap/pancake-swap-lib/contracts/utils/ReentrancyGuard.sol';
import '@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol';

// Inheritance
import './interfaces/IEDEXStakingToken.sol';

contract EDEXStakingToken is IEDEXStakingToken, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    struct stakingInfo {
        uint256 amount;
        uint256 releaseDate;
    }
    /* ========== STATE VARIABLES ========== */

    address public owner;
    IBEP20 public stakingToken;
    uint256 public stakingDuration;
    uint256 private _totalSupply;
    uint256 private _totalRewardsRequired;
    mapping(address => stakingInfo) private _balances;
    uint256 private basePct;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _stakingToken,
        uint256 _stakingDuration,
        uint256 _baseApy,
        address _owner
    ) public {
        require(_stakingDuration > 0, 'stakingDuration=0');
        stakingToken = IBEP20(_stakingToken);
        stakingDuration = _stakingDuration;
        owner = _owner;
        basePct = _baseApy;
    }

    modifier onlyOwner() {
        require(owner == msg.sender, 'Ownable: caller is not the owner');
        _;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function totalRewardsRequired() external view returns (uint256) {
        return _totalRewardsRequired;
    }

    function amountToContractRequired() external view returns (uint256) {
        uint256 balance = stakingToken.balanceOf(address(this));
        return
            (_totalRewardsRequired > 0 && _totalRewardsRequired > balance.sub(_totalSupply))
                ? _totalRewardsRequired.sub(balance.sub(_totalSupply))
                : 0;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account].amount;
    }

    function canWithdraw(address account) external view override returns (bool) {
        return _balances[account].amount > 0 && block.timestamp > _balances[account].releaseDate;
    }

    function canStake(address account) external view override returns (bool) {
        return _balances[account].releaseDate == 0;
    }

    function endStakingTime(address account) external view override returns (uint256) {
        return _balances[account].releaseDate;
    }

    function stake(uint256 amount) external override nonReentrant {
        require(amount > 0, 'Cannot stake 0');
        require(_balances[msg.sender].amount == 0, 'user already have deposit');
        _balances[msg.sender].amount = amount;
        _balances[msg.sender].releaseDate = block.timestamp + stakingDuration;
        _totalSupply = _totalSupply.add(amount);
        _totalRewardsRequired = _totalRewardsRequired.add(_getRewardsAmount(msg.sender));
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function _getRewardsAmount(address addr) private view returns (uint256) {
        uint256 amount = _balances[addr].amount;
        uint256 factor = uint256(10)**stakingToken.decimals();
        uint256 extra = 0;
        
        if(amount > 2000000 * factor || amount == 2000000 * factor) {
            extra = 15;
        } else if(amount > 1500000 * factor || amount == 1500000 * factor) {
            extra = 10;
        } else if (amount > 1000000 * factor || amount == 1000000 * factor) {
            extra = 5;
        } else if (amount > 500000 * factor || amount == 500000 * factor) {
            extra = 1;
        }
        uint256 individualAPY = basePct.add(extra).mul(1 ether);
        return ((amount.mul(individualAPY).div(365 days)).mul(stakingDuration)).div(100 * 1 ether);
    }

    function withdraw() public override nonReentrant {
        require(_balances[msg.sender].amount > 0, 'Cannot withdraw 0');
        require(block.timestamp > _balances[msg.sender].releaseDate, 'staking period is active');
        uint256 amount = _balances[msg.sender].amount;
        uint256 individualAPYReward = _getRewardsAmount(msg.sender);

        _totalSupply = _totalSupply.sub(amount);
        _totalRewardsRequired = _totalRewardsRequired.sub(individualAPYReward);
        _balances[msg.sender].amount = 0;
        _balances[msg.sender].releaseDate = 0;
        stakingToken.safeTransfer(msg.sender, amount.add(individualAPYReward));
        emit Withdrawn(msg.sender, amount, individualAPYReward);
    }

    function emergencyWithdraw(address _token) public override onlyOwner nonReentrant {
        IBEP20(_token).safeTransfer(msg.sender, IBEP20(_token).balanceOf(address(this)));
    }

    function exit() public override nonReentrant {
        require(_balances[msg.sender].amount > 0, 'no deposit');
        uint256 amount = _balances[msg.sender].amount;
        _balances[msg.sender].amount = 0;
        _balances[msg.sender].releaseDate = 0;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Exited(msg.sender, amount);
    }

    /* ========== EVENTS ========== */
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event Exited(address indexed user, uint256 amount);
}
