// contracts/CawName.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./CawNameURI.sol";

// AccessControlEnumerable,
contract CawName is 
  Context,
  ERC721Enumerable,
  Ownable
{

  IERC20 public immutable CAW;
  CawNameURI public uriGenerator;

  uint256 public totalCaw;

  address public minter;

  struct CawLike {
    uint64 senderTokenId;
    uint64 ownerTokenId;
    address sender;
    uint32 action;
    bytes8 cawId;
  }

  struct FollowData {
    address sender;
    uint64 senderTokenId;
    uint64 followeeTokenId;
    uint32 action;
  }

  struct CawData {
    string text;
    address sender;
    uint64 tokenId;
    uint32 action;
  }

  struct ReCawData {
    uint64 senderTokenId;
    uint64 ownerTokenId;
    address sender;
    uint32 action;
    bytes8 cawId;
  }

  string[] public usernames;

  // 4,294,967,296 should be enough actions for each user
  mapping(uint64 => uint32) public takenActionCount;

  mapping(uint64 => uint64) public followerCount;

  // mapping(uint256 => uint256) public previousOwners;
  mapping(uint64 => uint256) public cawOwnership;


  // tokenID => reducedSig => action
  mapping(uint64 => mapping(bytes8 => uint32)) public likes;

  // tokenID => reducedSig => action
  mapping(uint64 => mapping(bytes8 => bool)) public isVerified;

  uint256 public rewardMultiplier = 10**18;
  uint256 public precision = 30425026352721 ** 2;// ** 3;
  bytes32 public eip712DomainHash;

  constructor(address _caw, address _gui) ERC721("CAW NAME", "cawNAME") {
    eip712DomainHash = generateDomainHash();
    uriGenerator = CawNameURI(_gui);
    CAW = IERC20(_caw);
    // CAW = IERC20(0xf3b9569F82B18aEf890De263B84189bd33EBe452);
  }

  function setMinter(address _minter) public onlyOwner {
    minter = _minter;
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
    setCawBalance(tokenId, cawBalanceOf(tokenId) + amount);
    totalCaw += amount;
  }

  function withdraw(uint64 tokenId, uint256 amount) public {
    require(ownerOf(tokenId) == msg.sender, "can not withdraw from a CawName that you do not own");
    require(cawBalanceOf(tokenId) >= amount, "insufficent CAW balance");

    setCawBalance(tokenId, cawBalanceOf(tokenId) - amount);
    CAW.transfer(msg.sender, amount);
    totalCaw -= amount;
  }

  function cawBalanceOf(uint64 tokenId) public view returns (uint256){
    return cawOwnership[tokenId] * rewardMultiplier / (precision);
  }

  function spendAndDistribute(uint64 tokenId, uint256 amountToSpend, uint256 amountToDistribute) private {
    uint256 balance = cawBalanceOf(tokenId);
    amountToDistribute *= 10**18;
    amountToSpend *= 10**18;

    require(balance >= amountToSpend, 'insufficent CAW balance');
    uint256 newCawBalance = balance - amountToSpend;

    rewardMultiplier += rewardMultiplier * amountToDistribute / (totalCaw - balance);
    setCawBalance(tokenId, newCawBalance);
  }

  function addToBalance(uint64 tokenId, uint256 amount) internal {
    setCawBalance(tokenId, cawBalanceOf(tokenId) + (amount * 10**18));
  }

  function setCawBalance(uint64 tokenId, uint256 newCawBalance) internal {
    cawOwnership[tokenId] = precision * newCawBalance / rewardMultiplier;
  }

  function caw(
    uint8 v, bytes32 r, bytes32 s,
    CawData calldata cawData
  ) external {

    bytes memory hash = abi.encode(
      keccak256("CawData(string text,address sender,uint64 tokenId,uint32 action)"),
      keccak256(bytes(cawData.text)),
      cawData.sender,
      cawData.tokenId,
      cawData.action
    );

    // address signer = getSigner(hash, v, r, s);
    // require(signer == ownerOf(cawData.tokenId), "signer is not owner of this CawName");
    // require(takenActionCount[cawData.tokenId] == cawData.action - 1, "invalid action number");
    // require(cawData.sender == ownerOf(cawData.tokenId), "the correct token owner must be submitted");

    verifySignerAndActionId(
      v, r, s, hash, cawData.tokenId,
      cawData.sender, cawData.action
    );

    spendAndDistribute(cawData.tokenId, 5000, 5000);

    takenActionCount[cawData.tokenId] += 1;
    isVerified[cawData.tokenId][bytes8(r)] = true;
  }

  function likeCaw(
    uint8 v, bytes32 r, bytes32 s,
    CawLike calldata likeData
  ) external {
    // Do we need this? it adds more gas to keep track. Should we allow users to 'unlike' as well?
    // require(likedBy[likeData.tokenId][likeData.cawId][likeData.senderTokenId] == false, 'Caw has already been liked');
    bytes memory hash = abi.encode(
      keccak256("CawLike(uint64 senderTokenId,address sender,uint64 ownerTokenId,bytes8 cawId,uint32 action)"),
      likeData.senderTokenId, likeData.sender, likeData.ownerTokenId,
      likeData.cawId, likeData.action
    );

    verifySignerAndActionId(
      v, r, s, hash,
      likeData.senderTokenId,
      likeData.sender, likeData.action
    );

    spendAndDistribute(likeData.senderTokenId, 2000, 400);
    addToBalance(likeData.ownerTokenId, 1600);

    isVerified[likeData.senderTokenId][bytes8(r)] = true;
    takenActionCount[likeData.senderTokenId] += 1;
    likes[likeData.ownerTokenId][likeData.cawId] += 1;
  }

  function reCaw(
    uint8 v, bytes32 r, bytes32 s,
    ReCawData calldata reCawData
  ) external {
    bytes memory hash = abi.encode(
      keccak256("ReCawData(uint64 senderTokenId,uint64 ownerTokenId,address sender,uint32 action,bytes8 cawId)"),
      reCawData.senderTokenId, reCawData.ownerTokenId,
      reCawData.sender, reCawData.action,
      reCawData.cawId
    );

    verifySignerAndActionId(
      v, r, s, hash,
      reCawData.senderTokenId,
      reCawData.sender, reCawData.action
    );

    spendAndDistribute(reCawData.senderTokenId, 4000, 2000);
    addToBalance(reCawData.ownerTokenId, 2000);

    takenActionCount[reCawData.senderTokenId] += 1;
    isVerified[reCawData.senderTokenId][bytes8(r)] = true;
  }

  function followUser(
    uint8 v, bytes32 r, bytes32 s,
    FollowData calldata followData
  ) external {
    bytes memory hash = abi.encode(
      keccak256("FollowData(address sender,uint64 senderTokenId,uint64 followeeTokenId,uint32 action)"),
      followData.sender, followData.senderTokenId,
      followData.followeeTokenId, followData.action
    );

    verifySignerAndActionId(
      v, r, s, hash,
      followData.senderTokenId,
      followData.sender, followData.action
    );

    spendAndDistribute(followData.senderTokenId, 30000, 6000);
    addToBalance(followData.followeeTokenId, 24000);

    followerCount[followData.followeeTokenId] += 1;
    takenActionCount[followData.senderTokenId] += 1;
    isVerified[followData.senderTokenId][bytes8(r)] = true;
  }

  function verifySignerAndActionId(
    uint8 v, bytes32 r, bytes32 s,
    bytes memory hash, uint64 senderTokenId,
    address sender, uint32 action
  ) internal view {

    address signer = getSigner(hash, v, r, s);
    require(signer == ownerOf(senderTokenId), "signer is not owner of this CawName");
    require(takenActionCount[senderTokenId] == action - 1, "invalid action number");
    require(sender == ownerOf(senderTokenId), "the correct token owner must be submitted");
  }

  function getSigner(
    bytes memory hashedObject,
    uint8 v, bytes32 r, bytes32 s
  ) public view returns (address) {
    uint256 chainId;
    assembly {
      chainId := chainid()
    }

    bytes32 hash = keccak256(abi.encodePacked("\x19\x01", eip712DomainHash, keccak256(hashedObject)));
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

