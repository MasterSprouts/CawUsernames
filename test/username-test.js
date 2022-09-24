const IERC20 = artifacts.require("IERC20");
const CawNameURI = artifacts.require("CawNameURI");
const Usernames = artifacts.require("CawName");
const CawNameMinter = artifacts.require("CawNameMinter");
const ISwapper = artifacts.require("ISwapRouter");
// const ethereumjs = require("ethereumjs-util");


const {signTypedMessage} = require('@truffle/hdwallet-provider');
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const {
  encrypt,
  recoverPersonalSignature,
  recoverTypedSignature,
  TypedMessage,
  MessageTypes,
  SignTypedDataVersion,
  signTypedData,
} = require('@metamask/eth-sig-util');


const wethAddress = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
const cawAddress = '0xf3b9569f82b18aef890de263b84189bd33ebe452'; // CAW
const usdcAddress = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'; // USDC

var minter;
var swapper;
var usernames;
var uriGenerator;
var domain;
var token;

const dataTypes = {
  EIP712Domain: [
    { name: 'name', type: 'string' },
    { name: 'version', type: 'string' },
    { name: 'chainId', type: 'uint256' },
    { name: 'verifyingContract', type: 'address' },
  ],
  CawData: [
    { name: 'text', type: 'string' },
    { name: 'sender', type: 'address' },
    { name: 'tokenId', type: 'uint64' },
    { name: 'action', type: 'uint32' },
  ],
  CawLike: [
    { name: 'senderTokenId', type: 'uint64' },
    { name: 'sender', type: 'address' },
    { name: 'ownerTokenId', type: 'uint64' },
    { name: 'cawId', type: 'bytes8' },
    { name: 'action', type: 'uint32' },
  ],
  ReCawData: [
    { name: 'senderTokenId', type: 'uint64' },
    { name: 'ownerTokenId', type: 'uint64' },
    { name: 'sender', type: 'address' },
    { name: 'action', type: 'uint32' },
    { name: 'cawId', type: 'bytes8' },
  ],
  FollowData: [
    { name: 'sender', type: 'address' },
    { name: 'senderTokenId', type: 'uint64' },
    { name: 'followeeTokenId', type: 'uint64' },
    { name: 'action', type: 'uint32' },
  ]
};

const gasUsed = async function(transaction) {
  var fullTx = await web3.eth.getTransaction(transaction.tx);
  return BigInt(transaction.receipt.gasUsed) * BigInt(fullTx.gasPrice);
}

function timeout(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function signData(user, data) {
  var privateKey = web3.eth.currentProvider.wallets[user.toLowerCase()].getPrivateKey()
  return signTypedData({
    data: data,
    privateKey: privateKey,
    version: SignTypedDataVersion.V4
  });
}

async function sendCaw(user, tokenId, message, params = {}) {

  // console.log("will sha 3", domain);
  // const timestamp = Math.floor(new Date().getTime() / 1000)
  // var params = [1, tokenId, timestamp, message];
  // var hash = web3.utils.sha3([
  //   domain,
  //   ['uint256', 'uint256', 'tokenId', 'string'],
  //   // [action, tokenId, timestamp, text],
  //   params,
  // ]);
  // console.log("ABOUT TO SIGN hash", hash);
  // var sig = await web3.eth.personal.sign(hash, user);
  // console.log("ABOUT TO SIGN sig", sig);

  action = params.action;
  if (action == null) action = Number(await usernames.takenActionCount(tokenId));

  console.log("---");
  console.log("SEND CAW with action ",action);

  const cawData = {
    action: action + 1,
    sender: user,
    tokenId: tokenId,
    text: message,
  };


  var data = {
    primaryType: 'CawData',
    message: cawData,
    domain, 
    types: {
      EIP712Domain: dataTypes.EIP712Domain,
      CawData: dataTypes.CawData,
    },
  };
  // console.log('DATA', data)
  var sig = await signData(user, data);
  var sigData = verifyAndSplitSig(sig, user, data);

  t = await usernames.caw(sigData.v, sigData.r, sigData.s, cawData, {
    nonce: await web3.eth.getTransactionCount(user),
    from: user,
  });

  var fullTx = await web3.eth.getTransaction(t.tx);
  console.log("send caw GAS", BigInt(t.receipt.gasUsed));

  return {
    tx: t,
    sig: sig
  };
}

/*
  {
      cawSig: secondCawSig,
      sender: accounts[2],
      senderTokenId: 3,
      ownerTokenId: 2,
  };

*/
async function likeCaw(params) {

  action = params.action;
  if (action == null) action = Number(await usernames.takenActionCount(params.senderTokenId));

  console.log("---");
  console.log("Like CAW with action ", action);

  const likeData = {
    action: action + 1,
    senderTokenId: params.senderTokenId,
    sender: params.sender,
    ownerTokenId: params.ownerTokenId,
    cawId: params.cawSig.substring(0,18),
  };


  var data = {
    primaryType: 'CawLike',
    message: likeData,
    domain, 
    types: {
      EIP712Domain: dataTypes.EIP712Domain,
      CawLike: dataTypes.CawLike,
    },
  };
  // console.log('DATA', data)
  var sig = await signData(params.sender, data);
  var sigData = verifyAndSplitSig(sig, params.sender, data);

  t = await usernames.likeCaw(sigData.v, sigData.r, sigData.s, likeData, {
    nonce: await web3.eth.getTransactionCount(params.sender),
    from: params.sender,
  });

  var fullTx = await web3.eth.getTransaction(t.tx);
  console.log("like caw GAS", BigInt(t.receipt.gasUsed));

  return {
    tx: t,
    sig: sig
  };
}

async function followUser(params) {
  action = params.action;
  if (action == null) action = Number(await usernames.takenActionCount(params.senderTokenId));

  console.log("---");
  console.log("Like CAW with action ", action);

  const followData = {
    action: action + 1,
    senderTokenId: params.senderTokenId,
    sender: params.sender,
    followeeTokenId: params.followeeTokenId,
  };


  var data = {
    primaryType: 'FollowData',
    message: followData,
    domain, 
    types: {
      EIP712Domain: dataTypes.EIP712Domain,
      FollowData: dataTypes.FollowData,
    },
  };
  // console.log('DATA', data)
  var sig = await signData(params.sender, data);
  var sigData = verifyAndSplitSig(sig, params.sender, data);

  t = await usernames.followUser(sigData.v, sigData.r, sigData.s, followData, {
    nonce: await web3.eth.getTransactionCount(params.sender),
    from: params.sender,
  });

  var fullTx = await web3.eth.getTransaction(t.tx);
  console.log("like caw GAS", BigInt(t.receipt.gasUsed));

  return {
    tx: t,
    sig: sig
  };
}

function verifyAndSplitSig(sig, user, data) {
  console.log('SIG', sig)
  console.log('hashed SIG', web3.utils.soliditySha3(sig))
  
  const signatureSans0x = sig.substring(2)
  const r = '0x' + signatureSans0x.substring(0,64);
  const s = '0x' + signatureSans0x.substring(64,128);
  const v = parseInt(signatureSans0x.substring(128,130), 16)
  // console.log('v: ', v)
  // console.log('r: ', r)
  // console.log('s: ', s)
  const recoverAddr = recoverTypedSignature({data: data, signature: sig, version: SignTypedDataVersion.V4 })
  // console.log('recovered address', recoverAddr)
  // console.log('account: ', user)
  expect(recoverAddr).to.equal(user.toLowerCase())

  return { r, s, v };
}

async function deposit(user, tokenId, amount) {
  console.log("DEPOSIT", tokenId, (BigInt(amount) * 10n**18n).toString());

  var balance = await token.balanceOf(user)
  await token.approve(usernames.address, balance.toString(), {
    nonce: await web3.eth.getTransactionCount(user),
    from: user,
  });

  t = await usernames.deposit(tokenId, (BigInt(amount) * 10n**18n).toString(), {
    nonce: await web3.eth.getTransactionCount(user),
    from: user,
  });

  return t;
}

async function buyUsername(user, name) {

  var balance = await token.balanceOf(user)
  await token.approve(minter.address, balance.toString(), {
    nonce: await web3.eth.getTransactionCount(user),
    from: user,
  });

  t = await minter.mint(name, {
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


// Dust is inevitable, so this check
// uses 4 decimal places of precision
async function expectBalanceOf(tokenId, params = {}) {
  balance = await usernames.cawBalanceOf(tokenId);
  var value = BigInt(parseInt(params.toEqual * 10**5))/10n;

  // console.log('.. balance ..',balance.toString())
  balance = parseInt(BigInt(balance.toString()) / 10n ** 13n)/10
  // console.log('.. balance ..',balance)
  balance = Math.round(balance)
  // console.log('.. balance ..',balance)
  balance = BigInt(balance)

  console.log('Balance of', tokenId, ":", balance, "== expecting", value);
  expect(balance == value).to.equal(true);
}

contract('CawNames', function(accounts, x) {
  var addr2;
  var addr1;


  var account0;
  var account1;
  var account2;

  beforeEach(async function () {
    web3.eth.defaultAccount = accounts[0];
    uriGenerator = uriGenerator || await CawNameURI.deployed();
    console.log("URI Generator addr", uriGenerator.address);
    minter = minter || await CawNameMinter.deployed();
    usernames = usernames || await Usernames.deployed();
    token = token || await IERC20.at(cawAddress);
    swapper = await ISwapper.at('0x7a250d5630b4cf539739df2c5dacb4c659f2488d'); // uniswap

    domain = {
      chainId: 31337,
      name: 'CawNet',
      verifyingContract: usernames.address,
      version: '1'
    };
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
    } catch(err) { error = err.message; }
    expect(error).to.include('lowercase letters and numbers');
    error = null;
    console.log("SUCCESS 1")

    var name = 'userrrr';
    var cost = await minter.costOfName(name);
    balance = await token.balanceOf(accounts[2]);
    console.log("BALANCE:", balance.toString(), "COST:", cost.toString());

    tx = await buyUsername(accounts[2], name);
    console.log("SUCCESS 2")
    var balanceWas = balance;
    balance = await token.balanceOf(accounts[2])

    console.log("BALANCES:", BigInt(balanceWas) - BigInt(balance) );
    expect(BigInt(balanceWas) - BigInt(balance) == BigInt(cost)).to.equal(true);


    try {
      tx = await buyUsername(accounts[2], name);
    } catch(err) { error = err.message; }
    expect(error).to.include('has already been taken');
    error = null;
    console.log("SUCCESS 3")


    try {
      tx = await buyUsername(accounts[1], 'x');
    } catch(err) { error = err.message; }
    expect(error).to.include('do not have enough CAW');
    error = null;
    console.log("SUCCESS 4")


    try {
      tx = await buyUsername(accounts[2], 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa2');
    } catch(err) { error = err.message; }
    expect(error).to.include('must only consist of 1-255 lowercase letters');
    error = null;


    try {
      tx = await buyUsername(accounts[2], '');
    } catch(err) { error = err.message; }
    expect(error).to.include('must only consist of 1-255 lowercase letters');
    error = null;
    tx = await buyUsername(accounts[2], 'usernamenumber2');
    tx = await buyUsername(accounts[2], 'usernamenumber3');

    // console.log("generator addr", await usernames.uriGenerator());
    console.log("URI", await usernames.usernames(0));


    tx = await deposit(accounts[2], 1, 10000);
    tx = await deposit(accounts[2], 2, 40000);
    tx = await deposit(accounts[2], 3, 10000);
    console.log("Done deposit");

    await expectBalanceOf(1, {toEqual: 10000});
    await expectBalanceOf(2, {toEqual: 40000});
    await expectBalanceOf(3, {toEqual: 10000});

    var response = await sendCaw(accounts[2], 1, "the first caw message ever sent");
    console.log("FISRT CAW SENT!")


    var isVerfied = await usernames.isVerified(1, response.sig.substring(0,18));
    expect(isVerfied.toString()).to.equal('true');


    var rewardMultiplier = await usernames.rewardMultiplier();
    console.log("REWARD MUL", BigInt(rewardMultiplier).toString())

    // 5k caw gets spent from the sender, and distributed
    // among other caw stakers proportional to their ownership
    //
    // balance(1) => 10000 - 5000
    // balance(2) => 10000 + 5000*40000/(10000 + 40000)
    // balance(3) => 11000 + 5000*10000/(10000 + 40000)
    await expectBalanceOf(1, {toEqual: 5000});
    await expectBalanceOf(2, {toEqual: 44000});
    await expectBalanceOf(3, {toEqual: 11000});


    try {
      // It will fail if you try to replay the same call
      response = await sendCaw(accounts[2], 1, "the first caw message ever sent", {action: 0});
    } catch(err) { error = err.message; }
    expect(error).to.include('invalid action number');
    error = null;

    response = await sendCaw(accounts[2], 2, "the second caw message ever sent");
    var secondCawSig = response.sig;

    rewardMultiplier = await usernames.rewardMultiplier();
    console.log("REWARD MUL", BigInt(rewardMultiplier).toString())
    // 5k caw gets spent from the sender, and distributed
    // among other caw stakers proportional to their ownership
    //
    // balance(1) => 5000 + 5000*5000/(5000 + 11000)
    // balance(2) => 44000 - 5000
    // balance(3) => 11000 + 5000*11000/(5000 + 11000)

    await expectBalanceOf(1, {toEqual: 6562.5});
    await expectBalanceOf(2, {toEqual: 39000});
    await expectBalanceOf(3, {toEqual: 14437.5});


    await likeCaw({
      cawSig: secondCawSig,
      sender: accounts[2],
      senderTokenId: 3,
      ownerTokenId: 2,
    });

    var likes = await usernames.likes(2, secondCawSig.substring(0,18));
    await expect(likes.toString()).to.equal('1');

    // 2k caw gets spent from the sender, 400 distributed
    // among other caw stakers proportional to their ownership
    // 1600 added to the token that owns the liked caw

    // balance(1) => 6562.5 + 400*6562.5/(39000 + 6562.5)
    // balance(2) => 39000 + 400*39000/(39000 + 6562.5) + 1600
    // balance(3) => 14437.5 - 2000

    await expectBalanceOf(1, {toEqual: 6620.1132});
    await expectBalanceOf(2, {toEqual: 40942.3868});
    await expectBalanceOf(3, {toEqual: 12437.5});

    try {
      // It will fail if you try to replay the same call
      await likeCaw({
        cawSig: secondCawSig,
        sender: accounts[2],
        senderTokenId: 3,
        ownerTokenId: 2,
        action: 0
      });
    } catch(err) { error = err.message; }
    expect(error).to.include('invalid action number');
    error = null;





  });

});
