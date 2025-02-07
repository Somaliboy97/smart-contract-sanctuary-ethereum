/**
 *Submitted for verification at Etherscan.io on 2022-07-30
*/

pragma solidity >=0.8.7;

contract FrontRunMePls {
    event success();
    event fail();

    bytes32 public secretHash;

    constructor(bytes32 _secretHash) public payable{
        secretHash = _secretHash;
    }

    function withdrawAllPlss(string calldata _secret) external{
        if(keccak256(abi.encodePacked(_secret)) == secretHash) {
            uint256 _myBalance = address(this).balance;
            payable(msg.sender).transfer(_myBalance);
            emit success();
        }else{
            emit fail();
        }
    }
}