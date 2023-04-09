// contracts/CawName.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./CawNameURI.sol";

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';

// AccessControlEnumerable,
contract CawBalance is 
  AxelarExecutable,
  Context,
  Ownable
{

  IERC20 public immutable CAW;
  CawNameURI public uriGenerator;

  uint256 public totalCaw;

  address public cawActions;

  string[] public usernames;

  mapping(uint64 => uint256) public cawOwnership;

  uint256 public rewardMultiplier = 10**18;
  uint256 public precision = 30425026352721 ** 2;// ** 3;

  struct Token {
    uint256 tokenId;
    uint256 balance;
    string username;
  }

  constructor(address _caw, address _gui) {
    uriGenerator = CawNameURI(_gui);
    CAW = IERC20(_caw);
    // CAW = IERC20(0xf3b9569F82B18aEf890De263B84189bd33EBe452);
  }

  function setCawActions(address _cawActions) public onlyOwner {
    cawActions = _cawActions;
  }

  // create an ARTIST_ROLE ??
  function setUriGenerator(address _gui) public onlyOwner {
    uriGenerator = CawNameURI(_gui);
  }

  function tokenURI(uint256 tokenId) override public view returns (string memory) {
    return uriGenerator.generate(usernames[uint64(tokenId) - 1]);
  }

  function tokens(address user) external view returns (Token[] memory) {
    uint256 tokenId;
    uint256 balance = balanceOf(user);
    Token[] memory userTokens = new Token[](balance);
    for (uint64 i = 0; i < balance; i++) {
      tokenId = tokenOfOwnerByIndex(user, i);

      userTokens[i].balance = cawBalanceOf(uint64(tokenId));
      userTokens[i].username = usernames[tokenId - 1];
      userTokens[i].tokenId = tokenId;
    }
    return userTokens;
  }

  function cawBalanceOf(uint64 tokenId) public view returns (uint256){
    return cawOwnership[tokenId] * rewardMultiplier / (precision);
  }

  function spendAndDistribute(uint64 tokenId, uint256 amountToSpend, uint256 amountToDistribute) external {
    require(cawActions == _msgSender(), "caller is not the cawActions contract");

    uint256 balance = cawBalanceOf(tokenId);
    amountToDistribute *= 10**18;
    amountToSpend *= 10**18;

    require(balance >= amountToSpend, 'insufficent CAW balance');
    uint256 newCawBalance = balance - amountToSpend;

    rewardMultiplier += rewardMultiplier * amountToDistribute / (totalCaw - balance);
    setCawBalance(tokenId, newCawBalance);
  }

  function addToBalance(uint64 tokenId, uint256 amount) external {
    require(cawActions == _msgSender(), "caller is not the cawActions contract");

    setCawBalance(tokenId, cawBalanceOf(tokenId) + (amount * 10**18));
  }

  function setCawBalance(uint64 tokenId, uint256 newCawBalance) internal {
    cawOwnership[tokenId] = precision * newCawBalance / rewardMultiplier;
  }

  // This is the function that deposits caw into
  // the user's username.
  //
  // it is called from "addToCawBalance", on
  // the NFT contract on the Ethereum chian.
  function _execute(
    string calldata sourceChain_,
    string calldata sourceAddress_,
    bytes calldata payload_
  ) internal override {
    (uint64 tokenId, uint256 amount) = abi.decode(payload_, (uint256));

    deposit(tokenId, amount, sourceAddress_);
  }

  function transferOwnership(uint64 tokenId, address newAddress) {
  }

  function deposit(uint64 tokenId, uint256 amount, address owner) internal {
    setCawBalance(tokenId, cawBalanceOf(tokenId) + amount);
    totalCaw += amount;

    // is the sourceAddress_ the original message sender????
    // is the sourceAddress_ the original message sender????
    // is the sourceAddress_ the original message sender????
    // is the sourceAddress_ the original message sender????
    ownerOf[tokenId] = owner;

  }

}


