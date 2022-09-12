// contracts/ChurchEggs.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./CawNameURI.sol";

// AccessControlEnumerable,
contract CawName is 
  Context,
  ERC721Enumerable,
  Ownable
{

  IERC20 public immutable CAW = IERC20(0xf3b9569F82B18aEf890De263B84189bd33EBe452);
  CawNameURI public uriGenerator;

  string[] public usernames;
  mapping(uint256 => uint256) public actions;
  mapping(string => uint256) public idByUsername;
  mapping(uint256 => uint256) public cawBalanceOf;
  mapping(uint256 => uint256) public previousOwners;

  // tokenId => actionNumber => timestamp ?????????????
  mapping(uint256 => mapping(uint256 => uint256)) public actionTimestamps;

  uint256 public stakePool;
  bytes32 public eip712DomainHash;

  constructor(address _gui) ERC721("CAW NAME", "cawNAME") {
    eip712DomainHash = generateDomainHash();
    uriGenerator = CawNameURI(_gui);
  }

  function tokenURI(uint256 tokenId) override public view returns (string memory) {
    return uriGenerator.generate(usernames[tokenId - 1]);
  }

  function setUriGenerator(address _gui) public onlyOwner {
    uriGenerator = CawNameURI(_gui);
  }

  // This might be needed to validate CAWs on the
  // front end after a token has been transfered
  //
  // function _afterTokenTransfer(
  //   address from,
  //   address to,
  //   uint256 tokenId
  // ) internal virtual override {
  //   super._afterTokenTransfer(from, to, tokenId);
  //
  //   if (from != address(0))
  //     previousOwners[tokenId].add(from);
  // }

  function mint(string memory username) public {
    require(idByUsername[username] == 0, "Username has already been taken");
    require(isValidUsername(username), "Username must only consist of 1-255 lowercase letters and numbers");
    uint256 amount = costOfName(username);

    require(CAW.balanceOf(_msgSender()) >= amount, "You do not have enough CAW to make this purchase");
    require(CAW.allowance(_msgSender(), address(this)) >= amount, "You must approve CAW NAMES to spend your CAW");
    CAW.transferFrom(_msgSender(), address(0xdEAD000000000000000042069420694206942069), amount);

    usernames.push(username);
    uint256 newId = usernames.length;
    idByUsername[username] = newId;

    _safeMint(_msgSender(), newId);
  }

  function costOfName(string memory username) public pure returns (uint256) {
    uint8 usernameLength = uint8(bytes(username).length);
    uint256 amount;

    // FROM THE SPEC:
    //
    // Every username is unique, and may use a-z and 0-9,
    //   without the use of special characters (emojis, etc..,) or capital letters. 
    //
    // - Single Character username (rare!) BURN 1,000,000,000,000 ($89,985, $1,799,712, $17,997,120) 
    // - 2 Character username - BURN 240,000,000,000 CAW ($21,600, $432,000, $4,320,000) 
    // - 3 Character Username - BURN 60,000,000,000 CAW ($5400, $108,000, $1,080,000) 
    // - 4 Character Username - BURN 6,000,000,000 CAW ($540, $10,800 $108,000) 
    // - 5 Character username - BURN 200,000,000 CAW ($18, $360, $3600) 
    // - 6 Character username - BURN 20,000,000 CAW ($1.80, $36, $360) 
    // - 7 Character username -BURN 10,000,000 CAW (90c, $18, $180) 
    // - 8 Character and up username - BURN 1,000,000 CAW (9c, $1.80, $18) 


    if (usernameLength == 1)
      amount = 10 ** 12; // 1,000,000,000,000
    else if (usernameLength == 2)
      amount = 24 * 10 ** 10; // 240,000,000,000
    else if (usernameLength == 3)
      amount = 6 * 10 ** 10;  // 60,000,000,000
    else if (usernameLength == 4)
      amount = 6 * 10 ** 9;  // 6,000,000,000
    else if (usernameLength == 5)
      amount = 2 * 10 ** 8; // 200,000,000
    else if (usernameLength == 6)
      amount = 2 * 10 ** 7; // 20,000,000
    else if (usernameLength == 7)
      amount = 10 ** 7; // 10,000,000
    else amount = 10 ** 6; // 1,000,000

    return amount * 10**18;
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

  function isValidUsername(string memory _input) public pure returns (bool) {
    bytes memory input = bytes(_input);
    if (input.length == 0 || input.length > 255) return false;

    for (uint8 i = 0; i < input.length; i++) {
      uint8 char = uint8(input[i]);
      if (
        (char < 48 || char > 57) && // not a number
          (char < 97 || char > 122) // not a lowercase character
      ) return false;
    }

    return true;
  }

  function deposit(uint256 tokenId, uint256 amount) public {
    require(ownerOf(tokenId) == msg.sender, "can not deposit into a CawName that you do not own");

    CAW.transferFrom(msg.sender, address(this), amount);
    cawBalanceOf[tokenId] += amount;
  }

  function withdraw(uint256 tokenId, uint256 amount) public {
    require(ownerOf(tokenId) == msg.sender, "can not withdraw from a CawName that you do not own");
    require(cawBalanceOf[tokenId] >= amount, "withdraw amount is greater than this CAW balance");

    CAW.transfer(msg.sender, amount);
    cawBalanceOf[tokenId] -= amount;
  }

  function caw(
    uint8 v, bytes32 r, bytes32 s,
    uint256 action,
    uint256 tokenId,
    uint256 timestamp,
    string memory text
  ) external {
    bytes memory functionCall = abi.encode(
      keccak256("Caw(uint256 action,uint256 tokenId,uint256 timestamp,string text)"), action, tokenId, timestamp, text
    );
    address signer = getSigner(functionCall, v, r, s);
    require(signer == ownerOf(tokenId), "signer is not owner of this CawName");
    require(cawBalanceOf[tokenId] >= 5000, 'you need at least 5000 CAW to post a caw');

    actionTimestamps[tokenId][action] = timestamp;
    cawBalanceOf[tokenId] -= 5000;
    actions[tokenId] += 1;
    stakePool += 5000;
  }

  function likeCaw(
    uint8 v, bytes32 r, bytes32 s,
    uint256 senderTokenId,
    uint256 posterTokenId,
    uint256 cawId
  ) external {
    bytes memory functionCall = abi.encode(
      keccak256("Caw(uint256 cawId,uint256 senderTrokenId)"), posterTokenId, senderTokenId, cawId
    );
    address signer = getSigner(functionCall, v, r, s);
    require(signer == ownerOf(senderTokenId), "signer is not owner of this CawName");
    require(cawBalanceOf[senderTokenId] >= 2000, 'you need at least 2000 CAW to like a caw');

    cawBalanceOf[senderTokenId] -= 2000;
    cawBalanceOf[posterTokenId] += 1600;
    actions[senderTokenId] += 1;
    stakePool += 400;
  }

  function reCaw(
    uint8 v, bytes32 r, bytes32 s,
    uint256 posterTokenId,
    uint256 senderTokenId,
    uint256 cawId
  ) external {
    bytes memory functionCall = abi.encode(
      keccak256("Caw(uint256 posterTokenId,uint256 senderTokenId)"), posterTokenId, senderTokenId, cawId
    );
    address signer = getSigner(functionCall, v, r, s);
    require(signer == ownerOf(senderTokenId), "signer is not owner of this CawName");
    require(cawBalanceOf[senderTokenId] >= 4000, 'you need at least 4000 CAW to re-caw');

    cawBalanceOf[senderTokenId] -= 4000;
    cawBalanceOf[posterTokenId] += 2000;
    actions[senderTokenId] += 1;
    stakePool += 2000;
  }

  function follow(
    uint8 v, bytes32 r, bytes32 s,
    uint256 followerTokenId,
    uint256 followeeTokenId
  ) external {
    bytes memory functionCall = abi.encode(
      keccak256("Caw(uint256 followerTokenId,uint256 followeeTokenId)"), followeeTokenId, followerTokenId
    );
    address signer = getSigner(functionCall, v, r, s);
    require(signer == ownerOf(followerTokenId), "signer is not owner of this CawName");
    require(cawBalanceOf[followerTokenId] >= 30000, 'you need at least 30000 CAW to follow a user');

    cawBalanceOf[followerTokenId] -= 30000;
    cawBalanceOf[followerTokenId] += 24000;
    actions[followerTokenId] += 1;
    stakePool += 6000;
  }

  function getSigner(
    bytes memory functionCall,
    uint8 v, bytes32 r, bytes32 s
  ) public view returns (address) {
    uint256 chainId;
    assembly {
      chainId := chainid()
    }

    bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, keccak256(functionCall)));
    return ecrecover(hash, v,r,s);
  }

  function generateDomainHash() internal view returns (bytes32) {
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    return keccak256(
      abi.encode(
        keccak256(
          "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        ),
        keccak256(bytes("CawNet")),
        keccak256(bytes("1")),
        chainId,
        address(this)
      )
    );
  }

}

