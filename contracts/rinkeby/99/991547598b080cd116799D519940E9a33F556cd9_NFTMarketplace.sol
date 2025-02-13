// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "IERC721.sol";
import "Ownable.sol";
// import "ReentrancyGuard.sol";
import "IERC20.sol";


contract NFTMarketplace is Ownable{
   
    uint256 private platformFee;
    address private constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    struct ListNFT {
        address nft;
        uint256 tokenid;
        address payable seller;
        uint256 price;
        bool sold;
    }
    mapping(address => mapping(uint => ListNFT)) public list;

    struct OfferNFT {
        address nft;
        uint256 tokenid;
        address offerer;
        uint256 offerPrice;
        bool accepted;
    }
    mapping(address => mapping(uint256 => mapping(address => OfferNFT))) public offerNfts;

    struct auctionNft{
        address nft;
        uint256 tokenid;
        address payable owner;
        uint256 startprice;
        uint256 starttime;
        uint256 endtime;
        address last_bider;
        uint256 bidingvalue;
        address wineer;
        bool success;
    }
    mapping(address => mapping(uint256 => auctionNft)) private auctionNfts;
    
    event ListedNFT(address indexed nft,uint256 indexed tokenid,uint256 price,address indexed seller);
    event BoughtNFT(address indexed nft,uint256 indexed tokenid,uint256 price,address seller,address indexed buyer);

    constructor(uint _platformFee) public {
        platformFee = _platformFee;
    }
    function listnft(address _nft,uint256 _tokenid,uint256 _price) public {
        IERC721 nft = IERC721(_nft);
        require(nft.ownerOf(_tokenid) == msg.sender, "this nft owner can list only");
        nft.transferFrom(msg.sender, address(this), _tokenid);
        list[_nft][_tokenid] = ListNFT({
            nft: _nft,
            tokenid: _tokenid,
            seller: payable(msg.sender),
            price:_price,
            sold: false
        });
       emit ListedNFT(_nft, _tokenid,_price, msg.sender);
    }

    function cancelListedNFT(address _nft, uint256 _tokenId) external {
        ListNFT memory listedNFT = list[_nft][_tokenId];
        require(listedNFT.seller == msg.sender, "not listed owner");
        delete list[_nft][_tokenId];
        IERC721(_nft).transferFrom(address(this), msg.sender, _tokenId);
    }

    function makeoffer(address _nft,uint256 _tokenid,uint256 _offerprice) public {
        require(_offerprice > 0, "price can not 0");
        ListNFT memory nft = list[_nft][_tokenid];
        offerNfts[_nft][_tokenid][msg.sender] = OfferNFT({
            nft: nft.nft,
            tokenid: nft.tokenid,
            offerer: msg.sender,
            offerPrice: _offerprice,
            accepted: false
        });
    }

    function cancelOfferNFT(address _nft, uint256 _tokenId)external {
        OfferNFT memory offer = offerNfts[_nft][_tokenId][msg.sender];
        require(offer.offerer == msg.sender, "you cannot not offerer");
        // require(!offer.accepted, "offer already accepted");
        delete offerNfts[_nft][_tokenId][msg.sender];
    }

    function acceptofferNFT(address _nft,uint256 _tokenid,address _offerer)external{
        require(list[_nft][_tokenid].seller == msg.sender,"not listed owner");
        OfferNFT storage offer = offerNfts[_nft][_tokenid][_offerer];
        ListNFT storage lists = list[offer.nft][offer.tokenid];
        require(!lists.sold, "already sold");
        require(!offer.accepted, "offer already accepted");
        lists.sold = true;
        offer.accepted = true;
        uint256 offerPrice = offer.offerPrice;
        uint256 ownerprice=(offerPrice) - (offerPrice*platformFee/100);
        IERC20(WETH).transferFrom(offer.offerer,address(this),lists.price);
        IERC721(lists.nft).transferFrom(address(this),offer.offerer,lists.tokenid); 
        lists.seller.transfer(ownerprice);
    }

    function buyNFT(address _nft,uint256 _tokenid) external payable{
        ListNFT storage listedNft = list[_nft][_tokenid];
        require(!listedNft.sold, "nft already sold");
        require(msg.value == listedNft.price, "invalid price");
        listedNft.sold = true;
        IERC721(listedNft.nft).transferFrom(address(this),msg.sender,listedNft.tokenid);
        uint256 price =(msg.value) - (msg.value*platformFee/100);
        listedNft.seller.transfer(price);
        emit BoughtNFT(listedNft.nft,listedNft.tokenid,msg.value,listedNft.seller,msg.sender);
    }

    function create_auction(address _nft,uint256 _tokenid,uint256 _price,uint256 _starttime)public {
        IERC721 nft = IERC721(_nft);
        require(nft.ownerOf(_tokenid) == msg.sender, "this nft owner can list only");
        nft.transferFrom(msg.sender, address(this), _tokenid);
        auctionNfts[_nft][_tokenid] = auctionNft({
            nft: _nft,
            tokenid: _tokenid,
            owner: payable(msg.sender),
            startprice:_price,
            starttime:_starttime,
            endtime:_starttime + 3600,
            last_bider:msg.sender,
            bidingvalue:_price,
            wineer:msg.sender,
            success: false
        });
    }

    function cancel_auction(address _nft,uint256 _tokenid) public{
        auctionNft memory auction=auctionNfts[_nft][_tokenid];
        require(auction.owner == msg.sender,'you not owner off this nft');
        require(auction.starttime > block.timestamp,'auction alreday start');
        delete auctionNfts[_nft][_tokenid];
        IERC721(_nft).transferFrom(address(this), msg.sender, _tokenid);
    }

    function bid_auction(address _nft,uint256 _tokenid,uint256 _price) public{
        auctionNft memory auction=auctionNfts[_nft][_tokenid];
        require(auction.starttime <= block.timestamp,'auction not start');
        require(auction.endtime > block.timestamp,'auction is over');
        require(auction.last_bider != msg.sender,'alreday last bider you');
        require(auction.bidingvalue < _price,'please enter valid amount');
        auction.last_bider =msg.sender;
        auction.bidingvalue=_price;
        auction.wineer=msg.sender;
    }

    function result_auction(address _nft, uint256 _tokenid) public{
        require(!auctionNfts[_nft][_tokenid].success, "already resulted");
        auctionNft memory auction=auctionNfts[_nft][_tokenid];
        require(msg.sender == auction.owner || msg.sender == auction.last_bider,'only owner or winner call this function' );
        require(auction.endtime < block.timestamp,'auction not finish');
        auction.success = true;
        uint256 price=auction.bidingvalue;
        uint256 ownerprice= (price) - (price*platformFee/100);
        IERC20(WETH).transferFrom(auction.wineer,address(this),price);
        IERC721(auction.nft).transferFrom(address(this),auction.wineer,auction.tokenid); 
        auction.owner.transfer(ownerprice);
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*
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

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}