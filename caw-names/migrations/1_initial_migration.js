const CawName = artifacts.require("CawName");
const CawNameURI = artifacts.require("CawNameURI");
const CAW = artifacts.require("MintableCAW");

module.exports = async function (deployer) {
  await deployer.deploy(CawNameURI);
  var uriGenerator = await CawNameURI.deployed();

  console.log("URI generator", uriGenerator.address);
  await deployer.deploy(CawName, uriGenerator.address);
};
