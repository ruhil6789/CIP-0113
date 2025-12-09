# cip113

Write validators in the `validators` folder, and supporting functions in the `lib` folder using `.ak` as a file extension.

```aiken
validator my_first_validator {
  spend(_datum: Option<Data>, _redeemer: Data, _output_reference: Data, _context: Data) {
    True
  }
}
```

## Building

```sh
aiken build
```

## Configuring

**aiken.toml**
```toml
[config.default]
network_id = 41
```

Or, alternatively, write conditional environment modules under `env`.

## Testing

You can write tests in any module using the `test` keyword. For example:

```aiken
use config

test foo() {
  config.network_id + 1 == 42
}
```

To run all tests, simply do:

```sh
aiken check
```

To run only tests matching the string `foo`, do:

```sh
aiken check -m foo
```

## Documentation

If you're writing a library, you might want to generate an HTML documentation for it.

Use:

```sh
aiken docs
```

## Resources

Find more on the [Aiken's user manual](https://aiken-lang.org).



use aiken/list
use aiken/option
use aiken/builtin
use aiken/transaction
use aiken/datum
use aiken/value
use aiken/script_context
use aiken/crypto


[[dependencies]]
name = "aiken-lang/stdlib"
version = "v2.2.0"
source = "github"

[[dependencies]]
name = "aiken-lang/stdlib"
version = "v2"
source = "github"

<!-- [[dependencies]]
name = "aiken-lang/stdlib"
version = "2"
source = "github" -->






2. transferLogic.ak (Token-Specific Withdraw Scripts)

Two validators in one file:
a) transfer_logic - Standard Transfer Validation

Validates transfer amount limits
Checks recipient whitelist
Requires sender signatures
Enforces transfer cooldowns
Extensible with custom transfer proofs

b) third_party_transfer_logic - Admin Actions

Lock/Unlock tokens
Update metadata
Force transfers (emergency actions)
Requires admin signatures

How It Works Together

Token Registration (your existing code):

   User → Mints registry NFT → Creates RegistryNode UTxO
   RegistryNode includes: tokenPolicy, transferLogicScript hash, etc.
```

2. **Token Minting** (your existing code):
```
   User → Calls minting policy → Checks registry → Mints tokens
   Tokens go to programmableLogicBase address with UserState datum
```

3. **Token Transfer** (new):
```
   User → Spends from programmableLogicBase (Transfer redeemer)
   programmableLogicBase → Checks registry for transferLogicScript
   programmableLogicBase → Requires withdrawal from transferLogicScript
   transferLogicScript → Validates transfer rules → Approves
```

4. **Admin Actions** (new):
```
   Admin → Spends from programmableLogicBase (AdminAction redeemer)
   programmableLogicBase → Validates action
   third_party_transfer_logic → Checks admin signature → Approves
Key Integration Points

Registry lookup: Both validators read RegistryNode from reference inputs
Asset name validation: Uses same validate_asset_name_format logic as your minting policy
UserState: Links owner, custom data, lock status to each token holding

https://github.com/cardano-foundation/CIPs/pull/444/files
type RegistryNode {
    tokenPolicy: ByteArray,
    nextTokenPolicy: ByteArray, 
    transferLogicScript: ByteArray,
    userStateManagerHash: ByteArray,
    globalStateUnit: ByteArray, 
    thirdPartyTransferLogicScript: ByteArray
}