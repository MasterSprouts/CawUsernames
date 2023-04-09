// contracts/CawName.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./CawNameURI.sol";

import { AxelarExecutable } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol';
import { IAxelarGasService } from '@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol';

// AccessControlEnumerable,
contract CawName is 
  ERC721Enumerable,
  AxelarExecutable,
  Ownable,
  Context
{

  IERC20 public immutable CAW;
  CawNameURI public uriGenerator;

  // uint256 public totalCaw;

  address public minter;
  address public cawActions;

  string[] public usernames;

  mapping(uint64 => uint256) public unlockedCaw;

  struct Token {
    uint256 tokenId;
    uint256 balance;
    string username;
  }

  constructor(address _caw, address _gui) ERC721("CAW NAME", "cawNAME") {
    uriGenerator = CawNameURI(_gui);
    CAW = IERC20(_caw);
    // CAW = IERC20(0xf3b9569F82B18aEf890De263B84189bd33EBe452);
  }

  function setMinter(address _minter) public onlyOwner {
    minter = _minter;
  }

  function setCawActions(address _cawActions) public onlyOwner {
    cawActions = _cawActions;
  }

  // create an ARTIST_ROLE
  function setUriGenerator(address _gui) public onlyOwner {
    uriGenerator = CawNameURI(_gui);
  }

  function tokenURI(uint256 tokenId) override public view returns (string memory) {
    return uriGenerator.generate(usernames[uint64(tokenId) - 1]);
  }

  function mint(address sender, string memory username, uint64 newId) public {
    require(minter == _msgSender(), "caller is not the minter");
    usernames.push(username);
    _safeMint(sender, newId);
  }

  function nextId() public view returns (uint64) {
    return uint64(usernames.length) + 1;
  }

  function tokens(address user) external view returns (Token[] memory) {
    uint256 tokenId;
    uint256 balance = balanceOf(user);
    Token[] memory userTokens = new Token[](balance);
    for (uint64 i = 0; i < balance; i++) {
      tokenId = tokenOfOwnerByIndex(user, i);

      userTokens[i].balance = unlockedCaw[uint64(tokenId)];
      userTokens[i].username = usernames[tokenId - 1];
      userTokens[i].tokenId = tokenId;
    }
    return userTokens;
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  function deposit(uint64 tokenId, uint256 amount) public {
    require(ownerOf(tokenId) == msg.sender, "can not deposit into a CawName that you do not own");

    CAW.transferFrom(msg.sender, address(this), amount);
    addToCawBalance(tokenId, amount, msg.sender);
    // totalCaw += amount;
  }

  function withdraw(uint64 tokenId, uint256 amount) public {
    require(ownerOf(tokenId) == msg.sender, "can not withdraw from a CawName that you do not own");
    require(unlockedCaw[tokenId] >= amount, "insufficent CAW balance");

    unlockedCaw[tokenId] -= amount;
    CAW.transfer(msg.sender, amount);
    // totalCaw -= amount;
  }

  addToCawBalance(uint64 tokenId, uint256 value, address user) internal {
    bytes memory payload = abi.encode('Fantom', operator, tokenId, value);
    string memory stringAddress = address(this).toString();

    gasReceiver.payNativeGasForContractCall{
      value: msg.value,
    }(address(this), 'Fantom', stringAddress, payload, user);

    //Call remote contract.
    gateway.callContract('Fantom', stringAddress, payload);
  }

  function _afterTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override {
    // tell other chain about transfer?
    addToCawBalance(0, ownerOf(tokenId));
  }

  function unlock(uint64 tokenId, uint256 amount) internal {
    unlockedCaw[tokenId] += amount;
  }

  function _execute(
    string calldata sourceChain_,
    string calldata sourceAddress_,
    bytes calldata payload_
  ) internal override {
    (uint64 tokenId, uint256 amount) = abi.decode(payload_, (uint256));
    unlock(tokenId, amount);
  }

}

