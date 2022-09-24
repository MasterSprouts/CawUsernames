const CawName = artifacts.require("CawName");
const CawNameURI = artifacts.require("CawNameURI");
const CawNameMinter = artifacts.require("CawNameMinter");
const CAW = artifacts.require("MintableCAW");

module.exports = async function (deployer) {
  var caw = '0xf3b9569F82B18aEf890De263B84189bd33EBe452';
  await deployer.deploy(CawNameURI);
  var uriGenerator = await CawNameURI.deployed();

  console.log("URI generator", uriGenerator.address);
  await deployer.deploy(CawName, caw, uriGenerator.address);
  var cawNames = await CawName.deployed();

  console.log("DEPLOY: ", caw, cawNames.address)
  await deployer.deploy(CawNameMinter, caw, cawNames.address);
  var minter = await CawNameMinter.deployed();

  cawNames.setMinter(minter.address);
};
