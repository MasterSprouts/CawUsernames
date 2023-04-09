pragma solidity >=0.8.9 <0.9.0;
//SPDX-License-Identifier: MIT

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MintableCAW is ERC20 {

  constructor() ERC20('Mintable CAW', 'mCAW') { }

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }
}

