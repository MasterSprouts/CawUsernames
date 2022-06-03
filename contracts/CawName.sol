// contracts/ChurchEggs.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./CawNameURI.sol";

// AccessControlEnumerable,
contract CawName is 
  Context,
  ERC721Enumerable,
  Ownable
{

  // TODO:
  // Not using immutable for Rinkeby,
  // remove this line when deploying to mainnet:
  IERC20 public CAW = IERC20(0xf3b9569F82B18aEf890De263B84189bd33EBe452);
  // IERC20 public immutable CAW = IERC20(0xf3b9569F82B18aEf890De263B84189bd33EBe452);



  CawNameURI public uriGenerator;

  string[] public usernames;
  mapping(string => uint256) idsByUsername;

  constructor(address _gui, address _cawAddress) ERC721("CAW NAME", "cawNAME") {
    uriGenerator = CawNameURI(_gui);

    // TODO: 
    // Using MintableCaw for rinkeby:
    // Remove this line when deploying to the mainnet
    CAW = IERC20(_cawAddress);
  }

  function tokenURI(uint256 tokenId) override public view returns (string memory) {
    return uriGenerator.generate(usernames[tokenId - 1]);
  }

  function setUriGenerator(address _gui) public onlyOwner {
    uriGenerator = CawNameURI(_gui);
  }

  function mint(string memory username) public {
    require(idsByUsername[username] == 0, "Username has already been taken");
    require(isValidUsername(username), "Username must only consist of 1-255 lowercase letters and numbers");

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

    uint256 amount;
    uint8 usernameLength = uint8(bytes(username).length);
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

    require(CAW.balanceOf(_msgSender()) >= amount, "You do not have enough CAW to make this purchase");
    require(CAW.allowance(_msgSender(), address(this)) >= amount, "You must approve CAW NAMES to spend your CAW");
    CAW.transferFrom(_msgSender(), address(0xdEAD000000000000000042069420694206942069), amount * 10**18);

    usernames.push(username);
    uint256 newId = usernames.length;
    idsByUsername[username] = newId;

    _safeMint(_msgSender(), newId);
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

}

