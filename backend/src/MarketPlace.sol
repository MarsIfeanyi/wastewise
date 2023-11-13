// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {RwasteWise} from "./RwasteWise.sol";
import {WasteWise} from "./Wastewise.sol";

/**
 * @title MarketPlace: A smart contract for managing item listings in a marketplace.
 * @author Marcellus Ifeanyi, Mayowa Obisesan, Biliqis Onikoyi, Isaac Wanger, konyeri Joshua
 * @dev This MarketPlace contract allows users who have recycled their pet Bottles to easily redeem their receipt tokens.
 */
contract MarketPlace {
    /// @dev Structure to represent information about an item listing.
    struct ItemInfo {
        string name;
        string description;
        string image;
        uint256 price;
        uint256 deadline;
        address lister;
        uint256 itemId;
    }

    struct Transaction {
        uint date;
        Type typeOfTransaction;
        uint amountOfTokens;
    }

    enum Type {
        Recycle,
        Purchase
    }

    mapping(address => Transaction) transactions;

    /// @dev Mapping to store item information by their unique listing ID.
    mapping(uint256 => ItemInfo) public itemInfoToId;

    /// @dev The address of the administrator of the marketplace.
    address public admin;

    /// @dev The ID to assign to the next listing.
    uint256 public listingId;

    /* ERRORS */

    error MinPriceTooLow();
    error DeadlineTooSoon();
    error MinDurationNotMet();
    error InvalidSignature();
    error ListingDoesNotExist();
    error ListingNotActive();
    error PriceNotMet(int256 difference);
    error ListingExpired();
    error PriceMismatch(uint256 originalPrice);
    error NoImageUrl();
    error NotAdmin();
    error NotEnoughToken();

    /* EVENTS */

    RwasteWise rwasteWise;
    WasteWise wasteWise;

    constructor(address tokenAddress, address wasteWiseAddr) {
        rwasteWise = RwasteWise(tokenAddress);
        wasteWise = WasteWise(wasteWiseAddr);
    }

    modifier onlyAdmins() {
        bool isAdmin;
        for (uint i = 0; i < wasteWise.getAdmin().length; i++) {
            if (wasteWise.getAdmin()[i] == msg.sender) {
                isAdmin = true;
            }
        }
        require(isAdmin, "Not Admin");
        _;
    }

    function createListing(
        string calldata _name,
        string calldata _description,
        string calldata _image,
        uint _price,
        uint _deadline
    ) public onlyAdmins {
        if (_price < 0.01 ether) revert MinPriceTooLow();
        if (block.timestamp + _deadline <= block.timestamp)
            revert DeadlineTooSoon();
        if (_deadline - block.timestamp < 60 minutes)
            revert MinDurationNotMet();
        if (keccak256(abi.encode(_image)) == keccak256(abi.encode("")))
            revert NoImageUrl();
        // Append item information to storage.
        // append to Storage
        listingId++;
        ItemInfo storage newItemInfo = itemInfoToId[listingId];
        newItemInfo.name = _name;
        newItemInfo.description = _description;
        newItemInfo.image = _image;
        newItemInfo.price = _price;
        newItemInfo.deadline = _deadline;
        newItemInfo.lister = msg.sender;
        newItemInfo.itemId = listingId;
    }

    /// @dev Buy an item from the marketplace.
    /// @param _listingId The unique identifier of the item listing to buy.
    function buyListing(uint256 _listingId, uint256 quantity) public {
        ItemInfo memory newItemInfo = itemInfoToId[_listingId];
        if (newItemInfo.itemId != _listingId) revert ListingDoesNotExist();
        if (block.timestamp > newItemInfo.deadline) revert ListingNotActive();

        uint256 totalPrice = newItemInfo.price * quantity;
        if (rwasteWise.balanceOf(msg.sender) < totalPrice)
            revert NotEnoughToken();

        // transfer tokens from buyer to seller
        rwasteWise.transferFrom(msg.sender, address(this), totalPrice);

        // burn the tokens collected
        rwasteWise.burnReceipt(address(this), totalPrice);

        // Create a new transaction
        Transaction memory transaction;
        transaction.date = block.timestamp;
        transaction.typeOfTransaction = Type.Purchase;
        transaction.amountOfTokens = totalPrice;

        // Store the transaction
        transactions[msg.sender] = transaction;
    }

    /**
     * @dev Update the information of an existing item listing.
     * @param _name  The new name of the item.
     * @param _description New description of the item.
     * @param _listingId The unique identifier of the item listing to update.
     * @param _newPrice New price for the item.
     */
    function updateListing(
        string calldata _name,
        string calldata _description,
        uint256 _listingId,
        uint256 _newPrice
    ) public onlyAdmins {
        if (_listingId != listingId) revert ListingDoesNotExist();
        ItemInfo storage itemInfo = itemInfoToId[_listingId];
        itemInfo.name = _name;
        itemInfo.description = _description;
        itemInfo.price = _newPrice;
    }

    /**
     * @dev Get information about an item listing by its unique identifier.
     * @param _listingId The unique identifier of the item listing.
     * @return ItemInfo The information about the item listing.
     */
    function getItemInfo(
        uint256 _listingId
    ) public view returns (ItemInfo memory) {
        return itemInfoToId[_listingId];
    }

    function getAllItemInfo() public view returns (ItemInfo[] memory) {
        ItemInfo[] memory allItemInfo = new ItemInfo[](listingId);
        for (uint i = 0; i < listingId; i++) {
            allItemInfo[i] = itemInfoToId[i + 1];
        }
        return allItemInfo;
    }

    function getAllActiveItemInfo() private view returns (ItemInfo[] memory) {
        uint activeItemsLength;
        for (uint i = 0; i < listingId; i++) {
            ItemInfo memory itemInfo = itemInfoToId[i + 1];
            if (block.timestamp < itemInfo.deadline) {
                activeItemsLength++;
            }
        }
        ItemInfo[] memory allActiveItemInfo = new ItemInfo[](activeItemsLength);
        uint index;
        for (uint i = 0; i < listingId; i++) {
            ItemInfo memory itemInfo = itemInfoToId[i + 1];
            if (block.timestamp < itemInfo.deadline) {
                allActiveItemInfo[index] = itemInfoToId[i + 1];
                index++;
            }
        }
        return allActiveItemInfo;
    }
}
