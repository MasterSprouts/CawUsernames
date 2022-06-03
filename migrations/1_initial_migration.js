const CawName = artifacts.require("CawName");
const CawNameURI = artifacts.require("CawNameURI");
const CAW = artifacts.require("MintableCAW");

module.exports = async function (deployer) {
  await deployer.deploy(CawNameURI);
  var uriGenerator = await CawNameURI.deployed();

  await deployer.deploy(CAW);
  mCaw = await CAW.deployed();
  var cawAddress = mCaw.address;
  // cawAddress = '0xf3b9569F82B18aEf890De263B84189bd33EBe452';

  console.log("URI generator", uriGenerator.address, cawAddress);
  await deployer.deploy(CawName, uriGenerator.address, cawAddress);
};
