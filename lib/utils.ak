use aiken/collection/list
use aiken/collection/dict
use aiken/collection/pairs.{has_key}
use aiken/merkle_patricia_forestry.{Proof, from_root, insert, root, has}

pub fn update_trie_root(
  old_root: ByteArray,
  key: ByteArray,
  value: ByteArray,
  proof: Proof
) -> ByteArray {
  let trie = from_root(old_root)
  let new_trie = insert(trie, key, value, proof)
  root(new_trie)
}

pub fn check_in_trie(
  root_hash: ByteArray,
  key: ByteArray,
  expected_value: ByteArray,
  proof: Proof
) -> Bool {
  let trie = from_root(root_hash)
  has(trie, key, expected_value, proof)
}

// You can expand as needed (non-membership proof, etc). This becomes your shared logic for verifying blacklists/whitelists.

// You may also put util functions (signature check, asset queries, etc) in utils.ak.


// use lib/merkle_trie
// use aiken/collection/list
// use aiken/collection/pairs.{has_key}
// use cardano/transaction.{Transaction, Input, Output, OutputReference}
// use cardano/assets.{quantity_of}

// pub type TokenDatum {
//   policy_id: ByteArray,
//   token_name: ByteArray,
//   extra: Option<ByteArray>,
// }

// pub type TransferRedeemer {
//   from: ByteArray,      //-- PubKeyHash
//   to: ByteArray,        //-- PubKeyHash
//   amount: Int,
//   proof_of_registration_hash: Option<ByteArray>,
//   proof_wl: Option<(ByteArray, Proof)>,
//   proof_bl: Option<(ByteArray, Proof)>,
// }

// validator transfer_logic(
//   registry_addr: ByteArray,           //-- address of token registry
//   programmable_base_addr: ByteArray,
//   bl_enabled: Bool,
//   wl_enabled: Bool,
// ) {
//   spend(
//     datum: Option<TokenDatum>,
//     redeemer: TransferRedeemer,
//     own_ref: OutputReference,
//     tx: Transaction,
//   ) {
//     expect Some(td) = datum

//     //-- require signature by `from`
//     assert(list.has(tx.extra_signatories, redeemer.from), "missing from signature")

//    // -- optional: check registration proof
//     match redeemer.proof_of_registration_hash {
//       Some(reg_hash) -> {
//         // -- scan reference inputs or inputs for the registry datum
//         let found = list.any(tx.reference_inputs, fn(ref) {
//           expect InlineDatum(reg_datum) = ref.output.datum
//           blake2b(reg_datum) == reg_hash
//         }) or
//         list.any(tx.inputs, fn(i) {
//           expect InlineDatum(d) = i.output.datum
//           blake2b(d) == reg_hash
//         })
//         assert(found, "registry proof missing")
//       }
//       None -> ()
//     }

//    // -- enforce whitelist / blacklist checks if enabled
//     if wl_enabled {
//       expect Some((key_wl, proof_wl)) = redeemer.proof_wl
//       assert(merkle_trie.check_in_trie(reg_hash.unwrap(), redeemer.from, "whitelist", proof_wl), "not in whitelist")
//     }
//     if bl_enabled {
//       expect Some((key_bl, proof_bl)) = redeemer.proof_bl
//       assert(!merkle_trie.check_in_trie(reg_hash.unwrap(), redeemer.from, "blacklist", proof_bl), "in blacklist")
//     }

//     //-- enforce that an output carrying the token goes via programmable base
//     let outputs_ok = list.any(tx.outputs, fn(o) {
//       o.address == programmable_base_addr &&
//       quantity_of(o.value, td.policy_id, td.token_name) == redeemer.amount
//     })
//     assert(outputs_ok, "must go into programmable base")

//     assert(redeemer.amount > 0, "invalid amount")

//     true
//   }
// }

// // You need to integrate your trie proofs appropriately. The idea is you pass proofs in the redeemer and validate against the registry datum root.