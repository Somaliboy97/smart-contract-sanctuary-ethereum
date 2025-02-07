/**
 *Submitted for verification at Etherscan.io on 2022-07-26
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// EVM, Ethereum Virtual Machine
// Avalance, Fantom, Polygon

contract SimpleStorage {
    uint256 favoriteNumber; // This gets initialized to 0

    mapping(string => uint256) public nameToFavoriteNumber;

    struct People {
        uint256 favoriteNumber;
        string name;
    }

    // uint256[] public favoriteNumbersList;
    People[] public people;

    function store(uint256 _favoriteNumber) public virtual {
        favoriteNumber = _favoriteNumber;
    }

    //view, pure
    function retrieve() public view returns (uint256) {
        return favoriteNumber;
    }

    //calldata, memory, storage
    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        people.push(People(_favoriteNumber, _name));
        nameToFavoriteNumber[_name] = _favoriteNumber;
    }
}