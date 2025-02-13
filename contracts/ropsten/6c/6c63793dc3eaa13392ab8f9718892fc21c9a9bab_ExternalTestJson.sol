//SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

import "./ExternalTestLibraryJson.sol";

contract ExternalTestJson {

  address[] stack;

  function identity(address input) public returns (address) {
    stack.push(input);
    return ExternalTestLibraryJson.pop(stack);
  }

}

//SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

library ExternalTestLibraryJson {
  function pop(address[] storage list) external returns (address out) {
    out = list[list.length - 1];
    list.pop();
  }
}