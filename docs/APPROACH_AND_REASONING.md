# Approach and Reasoning

A decentralized social network comes with a number of difficult problems, especially when the
primary source of truth (the etherum blockchain) requires significant fees to store data.

The proposed approach (as implied by <a href='https://caw.is'>CAW manifesto</a>)
is to have a second source of truth, a decentralized database (possibly ARWeave or OrbitDB),
along side the ethereum blockchain.

Due to the open nature of a decentralized database, anyone will be able to post anything to
this database at any time, which allows for many avenues of data injection attacks.
The following is a list of security requirements:

```
  a) Only the owner of a CawName can make a post with that CawName
  b) A CawName must spend CAW (as specified by the manifesto) for each action to be valid 
  c) Actions sent from a CawName under a previous owner should still be valid
  d) A single action must only be processed on the blockchain once
```

Each of these requirements have been accounted for in the `verifySignature` method in the contract.


The proposed solution to these requirements is to use OrbitDB with the following decentralized databases:

```
  i)   A single global action-feed for 'pending actions'
  ii)  A single global caw-feed for all newly verified caws and re-caws
  iii) A CawName specific caw-feed containing caws posted by that CawName
  iv)  A hashtag specific caw-feed for each and every hashtag used
  v)   A CawName specific caw-feed containing the caws posted from the followers of the specified CawName
  vi)  A CawName specific non-caw-feed containing all actions posted from a CawName
```


When a user takes any action (cawing -posting a caw-, liking a caw, following a user, recawing a caw, tipping a user),
the front-end client will assemble the necessary data in the format of the struct ActionData found in the
CawName contract, as follows:

```
  struct ActionData {
    ActionType actionType;
    uint64 senderTokenId;
    uint64 receiverTokenId;
    uint256 tipAmount;
    uint64 timestamp;
    address sender;
    bytes32 cawId;
    string text;
  }
```

The user will sign this ActionData, and the front-end client will submit both the ActionData and the signature to the
global 'pending actions' database (i). If the action is a caw, it will submit it to the caw-feed for that cawName (iii).

In the case of a Caw, the `cawId` and `receiverTokenId` fields should be left empty (0x000...00, and 0 respectively),
and in the case of all other actions, the `text` field should be left empty (""). 

The actionType should be a uint8 which corresponds to the intended index of the following enum:

```
{ CAW, LIKE, RECAW, FOLLOW }
```

(e.g. 0 for CAW; 1 for LIKE; etc..)


Once there are enough pending actions, a validator will retreive them from the db and submit them to the `processActions` function
in the CawActions contract. This function verifies each signature, and spends and distributes the intended amounts of CAW. It then
uses the first 32 bytes of the signature as an acitonId, and marks it as "verified" so at a later point a client can easily check if
the action has been process and paid for.

If the action failed while being processed, the contract will emit an ActionRejected event along with the senderId, actionId,
and the reason of failure. If an action succeeds, it will emit an `ActionProcessed` event along with the senderId and the actionId.

Once each action is marked as successfully processed, the validator can then post those actions to the databases ii, iv, v, vi,
as dictated by the content and sender of the CAW. This logic will be built into the validator codebse, which will be runnable by
anyone who chooses to be a validator.

It's important to remember that before a validator processes an action, it will be publicly readable from the database,
but not yet paid-for on the blockchain. Because of this paradigm, it's important that any front-end client makes a request
to the blockchain to check on the validity and completeness of each of caw before displaying them to the user
(or at minimum, notes the unpaid caw as 'unverified' to the user).

To check the validity of a caw, the front-end client can make a call to `verifyActions` with an array of the `senderIds` and
a corresponding array of `actionIds`. This will return an array of booleans indicating whether or not the caw at the
corresponding index has been processed, paid for, and marked as verified.

With this returned data, the front-end client now knows which caws have valid signatures. But before rendering caws with valid signatures
to users, it is also important for the front-end client to verifiy the following:

  - All fields which are expected to be empty for the specified `actionType`, must be verified as empty.
    If this is not the case, it's possible that a neferious user could be using the data in these fields
    to forge a signature which immitates the signature of another valid action.

  - It must be verified that the specified data is in fact full, complete, and was sent alongside the specified signature.
    This can be verified by using the web3 `recoverTypedSignature` function, which uses the signature and the data to recover the address
    of the original signer. If the address of the signer matches the sender address within the ActionData, then we know that the data is 
    veracious.

Once the data and the signature are fully verified to be valid, the client can happily show it to users.
