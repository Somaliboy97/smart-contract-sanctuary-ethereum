// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "Ownable.sol";

// IERC20.sol is an interface
import "IERC20.sol";

import "AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    // The purpose of this contract:
    // 1. stake tokens
    // 2. unstake tokens
    // 3. issue tokens
    // 4. add allowed tokens
    // 5. get token value

    // list of Tokens is allowed to be staked
    address[] public allowedTokens;

    // mapping token address -> staker address -> amount
    // mapping the token address to staker address
    // also mapping the staker address to amount
    mapping(address => mapping(address => uint256)) public stakingBalance;

    // mapping staked address to number of unique tokens
    mapping(address => uint256) public uniqueTokensStaked;

    // list of stakers
    // address array
    address[] public stakers;

    IERC20 public dappToken;

    // mapping the token address and corresponding token's price feed
    mapping(address => address) public tokenPriceFeedMapping;

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function setPriceFeedContract(address _token, address _priceFeed)
        public
        onlyOwner
    {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    // issueTokens function is to give rewards to stakers
    // based on the amount they have staked.

    // onlyOwner is a modifer from Ownable.sol
    function issueTokens() public onlyOwner {
        // Issue tokens to all stakers
        for (
            uint256 stakerIndex = 0;
            stakerIndex < stakers.length;
            stakerIndex++
        ) {
            address recipient = stakers[stakerIndex];
            uint256 userTotalValue = getUserTotalValue(recipient);
            // because we transfer native tokens of this contract to user
            // and this contract owns these tokens, so we use "transfer" function
            dappToken.transfer(recipient, userTotalValue);
            // send them a token reward
            // based on their total value locked
        }
    }

    function getUserTotalValue(address _user) public view returns (uint256) {
        uint256 totalValue = 0;
        require(
            uniqueTokensStaked[_user] > 0,
            "No tokens staked! This poor peasant does not have any money to scam!"
        );
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            totalValue =
                totalValue +
                getUserSingleTokenValue(
                    _user,
                    allowedTokens[allowedTokensIndex]
                );
        }
        return totalValue;
    }

    function getUserSingleTokenValue(address _user, address _token)
        public
        view
        returns (uint256)
    {
        if (uniqueTokensStaked[_user] <= 0) {
            return 0;
        }
        // price of the token * stakingBalance[_token][_user]
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        // stakingBalance[_token][_user] is number of token with 18 zeros
        // price is with 8 zeros
        // so we need to divide 10**decimals to get the meaningful value
        return ((stakingBalance[_token][_user] * price) / 10**decimals);
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        // price feed address
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        uint256 decimals = priceFeed.decimals();
        return (uint256(answer), decimals);
    }

    function stakeTokens(uint256 _amount, address _token) public {
        // Q1: how much can they stake?
        // Q2: what tokens can they stake?
        require(_amount > 0, "Amount must be more than 0, you poor peasant!");
        require(
            tokenIsAllowed(_token),
            "This token is currently not allowed, you stupid asshole!"
        );
        // use transferfrom function
        // there are two transfer function in ERC20.sol
        // transfer function: if it is called from wallet owns tokens
        // transferfrom function: since TokenFarm contract does not own tokens
        //      so we use transferfrom function
        // transfterfrom function has to call approve function first

        // "this" is keyword in solidty mean the contract we are in
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        // update the user's amount of unique token.
        updateUniqueTokensStaked(msg.sender, _token);

        // stakingBalance[_token][msg.sender] indicate amount
        stakingBalance[_token][msg.sender] =
            stakingBalance[_token][msg.sender] +
            _amount;

        // when user call "stakeTokens" function
        // and has uniqueTokensStaked[msg.sender] == 1
        // means this is the fisrt time this user stakes token
        // so we need to add this user to staker list
        // if uniqueTokensStaked[msg.sender] == 2
        // means this user has staked before, so no need to add to staker list.
        if (uniqueTokensStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    function unstakeTokens(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(
            balance > 0,
            "Staking balance cannot be 0, you don't have this token at all, you poor filthy peasant!"
        );
        // transfer out all tokens to users.
        IERC20(_token).transfer(msg.sender, balance);
        // reset the balance for that token as 0
        stakingBalance[_token][msg.sender] = 0;
        // reduce the unique token amount under this user by 1
        uniqueTokensStaked[msg.sender] = uniqueTokensStaked[msg.sender] - 1;
    }

    // when msg.sender call "stakeTokens" function
    // means this user has this kind of token and want to stake them
    // if stakingBalance[_token][_user] <= 0 means
    // the staking history record shows user had not staked this token before
    // so the amount of this user's unique token should increase by 1.

    // interal means only this contract can call this function.
    function updateUniqueTokensStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            // uniqueTokensStaked[_user] indicate the number of unique token under that user
            uniqueTokensStaked[_user] = uniqueTokensStaked[_user] + 1;
        }
    }

    // onlyOwner is a modifer from Ownable.sol
    function addAllowedtokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function tokenIsAllowed(address _token) public returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}