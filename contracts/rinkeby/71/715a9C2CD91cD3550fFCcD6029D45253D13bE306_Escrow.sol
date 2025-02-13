// SPDX-License-Identifier: ISC
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./utils/ERC721/IERC721Receiver.sol";

/// @title The Escrow Implementation Contract
/// @author [email protected]
/// @notice Contract that has all the Escrow logic, which shall be used by the Escrow Factory
contract Escrow is Initializable, ReentrancyGuardUpgradeable {
    constructor () {
        //
    }

    bool public isFreezed;

    address public payer;
    address public beneficiary;
    address public judge;

    address[] public participants;
    mapping(address => bool) public participantExists;

    mapping(address => uint256) public getBalanceOf;
    mapping(address => uint256) public getApprovedBalanceOf;

    /// @notice Constructor function for the Escrow Contract Instances
    function initialize(
        address _payer,
        address _beneficiary,
        address _judge
    )
        public 
        payable
        initializer
    {
        require(_payer != _beneficiary);
        require(_payer != _judge);
        require(_beneficiary != _judge);

        payer = _payer;
        beneficiary = _beneficiary;
        judge = _judge;
        isFreezed = false;
    }




    /// @notice Get Balance of the Escrow Contract
    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }




    // Events
    event ReceivedFunds(
        address indexed by,
        uint256 fundsInwei,
        uint256 timestamp
    );
    event EscrowFreezed (uint256 timestamp);
    event EscrowUnfreezed (uint256 timestamp);
    event NewParticipant (address indexed participant, uint256 timestamp);
    event ApprovedFunds (
        address indexed fromAccount,
        address indexed actionedBy,
        address indexed beneficiary,
        uint256 amount,
        uint256 timestamp
    );
    event Refunded (
        address indexed actionedBy,
        address indexed payer,
        uint256 amount,
        uint256 timestamp
    );
    event Withdrew (
        address indexed actionedBy,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    event JudgeRuled (
        address[] addresses,
        uint256[] balances,
        uint256[] approvedBalances,
        uint256 timestamp
    );




    // Fallbacks
    fallback() external virtual payable {
        emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
        getBalanceOf[msg.sender] = getBalanceOf[msg.sender] + msg.value;
        addParticipant(msg.sender);
    }
    receive() external virtual payable {
        emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
        getBalanceOf[msg.sender] = getBalanceOf[msg.sender] + msg.value;
        addParticipant(msg.sender);
    }




    // Modifiers
    modifier freezeCheck() {
        require(
            isFreezed == false,
            "Escrow freezed"
        );
        _;
    }
    modifier judgeCheck() {
        require(
            msg.sender == judge,
            "you arent a judge"
        );
        _;
    }
    modifier beneficiaryOrJudgeCheck() {
        require(
            msg.sender == beneficiary || msg.sender == judge,
            "you arent a beneficiary"
        );
        _;
    }




    // Private Functions
    function addParticipant(address _participant) internal {
        if (
            participantExists[_participant] != true &&
            _participant != payer && 
            _participant != beneficiary
        ) {
            participants.push(_participant);
            participantExists[_participant] = true;
            emit NewParticipant (_participant, block.timestamp);
        }
    }




    // Approve
    function approve (
        address _from,
        address _beneficiary,
        uint256 _amount,
        bool attemptPayment
    ) nonReentrant freezeCheck external returns (
        address amountFrom,
        address amountBeneficiary,
        uint256 amountApproved,
        bool isPaymentAttempted
    ) {
        require(msg.sender == _from || msg.sender == judge, "unauthorized approve");
        require(_amount <= getBalanceOf[_from], "Insufficient Balance");

        getBalanceOf[_from] = getBalanceOf[_from] - _amount;

        addParticipant(_from);
        addParticipant(_beneficiary);

        if (attemptPayment) {
            (bool success, ) = payable(_beneficiary).call{value: _amount}("");
            require(success, "Payment failed");
        } else {
            getApprovedBalanceOf[_beneficiary] = getApprovedBalanceOf[_beneficiary] + _amount;
        }

        emit ApprovedFunds (_from, msg.sender, _beneficiary, _amount, block.timestamp);

        return (
            _from,
            _beneficiary,
            _amount,
            attemptPayment
        );
    }




    // Withdraw
    function withdraw (
        uint256 _amount,
        address _to
    ) nonReentrant freezeCheck external returns (
        uint256 amount,
        address to
    ) {
        require(_amount <= getApprovedBalanceOf[msg.sender], "Insufficient Balance");

        getApprovedBalanceOf[msg.sender] = getApprovedBalanceOf[msg.sender] - _amount;

        (bool success, ) = payable(_to).call{value: _amount}("");
        require(success, "Withdraw failed");

        emit Withdrew (msg.sender, _to, _amount, block.timestamp);

        return (
            _amount,
            _to
        );
    }



    // Refund
    function refund (
        address _payer,
        uint256 _amount,
        bool attemptPayment
    ) 
        nonReentrant
        freezeCheck
        beneficiaryOrJudgeCheck
        external 
    returns (
        address amountBeneficiary,
        uint256 amountApproved,
        bool isPaymentAttempted
    ) {
        require(msg.sender != _payer, "Unauthorized refund");

        require(_amount <= getBalanceOf[_payer], "Insufficient Balance");

        getBalanceOf[_payer] = getBalanceOf[_payer] - _amount;

        if (attemptPayment) {
            (bool success, ) = payable(_payer).call{value: _amount}("");
            require(success, "Refund failed");
        } else {
            getApprovedBalanceOf[_payer] = getApprovedBalanceOf[_payer] + _amount;
        }

        emit Refunded (msg.sender, _payer, _amount, block.timestamp);

        return (
            _payer,
            _amount,
            attemptPayment
        );
    }




    // judgeRule
    function judgeRule (
        address[] memory _addresses,
        uint256[] memory _balances,
        uint256[] memory _approvedBalances
    ) nonReentrant external returns (
        address[] memory addresses,
        uint256[] memory balances,
        uint256[] memory approvedBalances
    ) {
        require(msg.sender == judge, "Unauthorized judgeRule");
        require(_addresses.length == _approvedBalances.length, "unequal length");
        require(_addresses.length == _balances.length, "unequal length");

        require(_addresses[0] == payer, "first address must be payer");
        require(_addresses[1] == beneficiary, "second address must be beneficiary");
        require(_addresses[2] == judge, "third address must be judge");

        // Check if balances of everyone involved are collectively less than or equal to the total contract balance
        uint256 _totalBalance;

        for (uint256 i = 0; i < _addresses.length; i++) {
            uint256 _approvedBalance = _approvedBalances[i];
            uint256 _balance = _approvedBalances[i];
            _totalBalance += _approvedBalance + _balance;
        }

        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            uint256 approvedBalanceOfParticipant = getApprovedBalanceOf[participant];
            uint256 balanceOfParticipant = getBalanceOf[participant];
            _totalBalance += approvedBalanceOfParticipant + balanceOfParticipant;

            // Check if the Participant is also in the Addresses array, if so, reduce their total from the tally
            for (uint256 j = 0; j < _addresses.length; j++) {
                if (participantExists[_addresses[i]] == true) {
                    _totalBalance -= approvedBalanceOfParticipant + balanceOfParticipant;
                }
            }
        }

        require(_totalBalance <= getBalance(), "balances exhausted");

        // Distribute the Funds
        for (uint256 i = 0; i < _addresses.length; i++) {
            address _address = _addresses[i];
            uint256 _approvedBalance = _approvedBalances[i];

            getApprovedBalanceOf[_address] = _approvedBalance;
            getBalanceOf[_address] = _approvedBalance;
        }

        emit JudgeRuled (
            _addresses,
            _balances,
            _approvedBalances,
            block.timestamp
        );

        return (
            _addresses,
            _balances,
            _approvedBalances
        );
    }




    // toggleFreeze
    function toggleFreeze() nonReentrant external returns (bool _isFreezed) {
        require(msg.sender == judge, "Unauthorized toggleFreeze");

        if (isFreezed) {
            isFreezed = false;
            emit EscrowUnfreezed (block.timestamp);
        } else {
            isFreezed = true;
            emit EscrowFreezed (block.timestamp);
        }

        return isFreezed;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                /// @solidity memory-safe-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}