const IERC20 = artifacts.require("IERC20");
const CawNameURI = artifacts.require("CawNameURI");
const Usernames = artifacts.require("CawName");
const ISwapper = artifacts.require("ISwapRouter");


const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');


const wethAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
const cawAddress = '0xf3b9569f82b18aef890de263b84189bd33ebe452'; // CAW
const usdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'; // USDC

var swapper;
var usernames;
var uriGenerator;
var token;

const gasUsed = async function(transaction) {
  var fullTx = await web3.eth.getTransaction(transaction.tx);
  return BigInt(transaction.receipt.gasUsed) * BigInt(fullTx.gasPrice);
}

function timeout(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function buyUsername(user, name) {

  var balance = await token.balanceOf(user)
  await token.approve(usernames.address, balance.toString(), {
    nonce: await web3.eth.getTransactionCount(user),
    from: user,
  });

  t = await usernames.mint(name, {
    nonce: await web3.eth.getTransactionCount(user),
    from: user,
  });

  return t;
}

async function buyToken(user, eth) {
  console.log("TOKEN:", token.address, swapper.address);
  t = await swapper.getAmountsOut(
    '100000000000000000',[
    wethAddress,
    usdcAddress,
    token.address,
  ]);
  console.log("TTTTT", t.toString());

  t = await swapper.swapExactETHForTokens('0',[
    wethAddress,
    usdcAddress,
    token.address,
  ], user, Date.now() + 1000000, {
    nonce: await web3.eth.getTransactionCount(user),
    value: BigInt(eth * 10**18).toString(),
    from: user,
  });

  t = await swapper.getAmountsOut(
    '100000000000000000',[
    wethAddress,
    usdcAddress,
    token.address,
  ]);
  console.log("TTTTT", t.toString());

  return  (await token.balanceOf(user)).toString();
}

contract('CawNames', function(accounts) {
  var addr2;
  var addr1;


  var account0;
  var account1;
  var account2;

  beforeEach(async function () {
    web3.eth.defaultAccount = accounts[0].address;
    uriGenerator = uriGenerator || await CawNameURI.deployed();
    console.log("URI Generator addr", uriGenerator.address);
    usernames = usernames || await Usernames.deployed(uriGenerator.address);
    token = token || await IERC20.at(cawAddress);
    swapper = await ISwapper.at('0x7a250d5630b4cf539739df2c5dacb4c659f2488d'); // uniswap
  });

  it("", async function() {
    await buyToken(accounts[2], 100);
    var balance = await token.balanceOf(accounts[2])
    console.log('BALANCE: ', (balance).toString());
    //
    // expect((await token.balanceOf(accounts[2])) == 0).to.equal(true);
    //
    // //  Expect this to not work:
    var error;
    var tx;
    try {
      tx = await buyUsername(accounts[2], 'username&');
    } catch(err) {
      error = err.message;
    }
    expect(error).to.include('lowercase letters and numbers');
    error = null;
    console.log("SUCCESS 1")

    tx = await buyUsername(accounts[2], 'user');
    console.log("SUCCESS 2")
    var balanceWas = balance;
    balance = await token.balanceOf(accounts[2])

    console.log("BALANCES:", BigInt(balanceWas) - BigInt(balance) );
    expect(BigInt(balanceWas) - BigInt(balance) == 6000000000n * 10n**18n).to.equal(true);


    try {
      tx = await buyUsername(accounts[2], 'user');
    } catch(err) {
      error = err.message;
    }
    expect(error).to.include('has already been taken');
    error = null;


    try {
      tx = await buyUsername(accounts[1], 'x');
    } catch(err) {
      error = err.message;
    }
    expect(error).to.include('do not have enough CAW');
    error = null;


    try {
      tx = await buyUsername(accounts[2], 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2');
    } catch(err) {
      error = err.message;
    }
    expect(error).to.include('must only consist of 1-255 lowercase letters');
    error = null;


    try {
      tx = await buyUsername(accounts[2], '');
    } catch(err) {
      error = err.message;
    }
    expect(error).to.include('must only consist of 1-255 lowercase letters');
    error = null;
      tx = await buyUsername(accounts[2], 'vitalikbuterin');

    console.log("generator addr", await usernames.uriGenerator());
    console.log("URI", await usernames.usernames(0));

    console.log("URI", await usernames.tokenURI(1));

    console.log("URI", await usernames.tokenURI(2));



  });

});
