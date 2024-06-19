//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
contract simpleTarget {

    uint public alphaBlockNumber;
    uint public counter;

    event AlphaNoArgsEvent(address indexed sender, uint256 _counter, uint256 alphaBlockNumber);

    function setAlphaNoArgs() external returns (bool) {
        alphaBlockNumber = block.number;
        counter++;
        emit AlphaNoArgsEvent(msg.sender,counter,alphaBlockNumber);
        return true;
    }

} 