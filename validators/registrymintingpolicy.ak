use aiken/collection/dict.{Dict, from_ascending_pairs_with}
use aiken/collection/list
use aiken/crypto.{
  Blake2b_224, Blake2b_256, Hash, Script, Signature, VerificationKey,
}
use aiken/primitive/bytearray
use cardano/address.{Address}
use cardano/assets.{AssetName, PolicyId, Value}
// use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/script_context.{Minting, ScriptContext}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, ScriptPurpose, Spend,
  Transaction, TransactionId, Withdraw,
}
use types/registry.{RegistryConfig, RegistryNode}



/// Configuration parameters for the registry
pub type MintRedeemer {
  MintToken {
    token_symbol: ByteArray,
    policy_id: PolicyId,
    asset_name: ByteArray,
    amount: Int,
  }
}

validator token_minting_policy(config: RegistryConfig) {
  mint(redeemer: MintRedeemer, own_policy: PolicyId, transaction: Transaction) {
    when redeemer is {
      MintToken { token_symbol, policy_id, asset_name, amount } -> {
        // 1. Verify amount is positive
        expect amount > 0
        // 2. Verify the policy_id matches the current minting policy
        expect policy_id == own_policy
        // 3. Check registry to ensure token is registered
        expect
          check_registry(token_symbol, policy_id, transaction.reference_inputs)
        True
      }
    }
  }

  else(_) {
    fail
  }
}


/// Check if the token is registered in the registry
fn check_registry(
  token_symbol: ByteArray,
  policy_id: PolicyId,
  reference_inputs: List<Input>,
) -> Bool {
  reference_inputs
    |> list.any(
        fn(input) {
          when input.output.datum is {
            InlineDatum(datum_data) -> {
              // Cast the datum to RegistryNode type
              expect node: RegistryNode = datum_data
              // Check if this node matches our token
              node.globalStateUnit == token_symbol && node.tokenPolicy == policy_id
            }
            _ -> False
          }
        },
      )
}
