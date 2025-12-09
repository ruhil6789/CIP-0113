// use aiken/builtin
// use aiken/collection/list
// use aiken/collection/dict
// use cardano/assets.{PolicyId}
// use cardano/transaction.{Transaction, MintingPolicy, Output, Input}
// use cardano/address.{Address, Credential, Script, VerificationKey}

// pub type IssuanceParams {
//   issuers: List<ByteArray>,          //-- List of PKHs allowed to mint/burn
//   registry_ref: Option<ByteArray>,   //-- Optional: hash of valid registry datum
// }

// pub type IssuanceRedeemer {
//   op: ByteArray,  //-- "mint" or "burn"
//   amount: Int
// }

// validator issuance_policy(params: IssuanceParams) {
//   mint(redeemer: IssuanceRedeemer, _policy: PolicyId, tx: Transaction) {
//     let IssuanceParams { issuers, registry_ref } = params
//     let IssuanceRedeemer { op, amount } = redeemer

//     assert(amount > 0, "amount must be positive")

//     // -- check if signer is authorized
//     assert(is_authorized_issuer(tx, issuers), "unauthorized issuer")
// trace("Message you want to log")

//    // -- if registry_ref is provided, confirm it's present in inputs
//   match registry_ref {
//   Some(expected_hash) -> {
//     let found = list.any(
//       tx.inputs,
//       fn(input: Input) {
//         match input.output.datum {
//           Some(d) -> builtin.blake2b_256(d) == expected_hash,
//           None    -> false,
//         }
//       },
//     )
//     assert(found, "missing or invalid registry reference")
//   }
//   None -> ()
// }


//     true
//   }

//   else(_) {
//     false
//   }
// }

// fn is_authorized_issuer(tx: Transaction, issuers: List<ByteArray>) -> Bool {
//   issuers.any(fn(pkh: ByteArray) {
//     list.has(tx.extra_signatories, pkh)
//   })
// }
