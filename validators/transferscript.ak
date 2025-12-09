// type TransferDatum {
//   owner: Hash  // Owner's pubkey hash
//   amount: Int  // Current token balance
// }

// type TransferRedeemer {
//   Transfer { to: Hash, amount: Int }
//   UpdateLogic { new_transfer_logic: Hash<Blake2b_224, Script> }
// }

// validator transfer_validator(config: RegistryConfig) {
//   spend(datum: TransferDatum, redeemer: TransferRedeemer, ctx: ScriptContext) {
//     let ScriptContext { transaction, purpose } = ctx
    
//     when purpose is {
//       Spend(output_ref) -> {
//         // Find the input being spent
//         expect Some(Input { output: Output { address, .. }, .. }) = 
//           list.find(transaction.inputs, fn(input) { input.output_reference == output_ref })
        
//         when redeemer is {
//           Transfer { to, amount } -> {
//             // 1. Verify transfer amount is positive
//             amount > 0 &&
            
//             // 2. Verify sender has sufficient balance
//             datum.amount >= amount &&
            
//             // 3. Verify sender signature
//             list.has(transaction.extra_signatories, datum.owner) &&
            
//             // 4. Verify outputs properly transfer tokens
//             validate_transfer_outputs(transaction.outputs, datum.owner, to, amount) &&
            
//             // 5. Verify token is registered
//             token_is_registered_in_transfer(transaction.reference_inputs, address)
//           }
          
//           UpdateLogic { new_transfer_logic } -> {
//             // Only owner can update transfer logic
//             list.has(transaction.extra_signatories, datum.owner) &&
//             // Verify the new logic script is registered
//             validate_new_logic_script(new_transfer_logic, transaction.reference_inputs)
//           }
//         }
//       }
//       _ -> false
//     }
//   }
// }

// // Validate transfer outputs
// fn validate_transfer_outputs(
//   outputs: List<Output>,
//   from: Hash,
//   to: Hash,
//   amount: Int
// ) -> Bool {
//   let sender_output = outputs
//     |> list.find(fn(output) {
//         output.address.payment_credential == VerificationKeyCredential(from)
//       })
  
//   let receiver_output = outputs
//     |> list.find(fn(output) {
//         output.address.payment_credential == VerificationKeyCredential(to)
//       })
  
//   when (sender_output, receiver_output) {
//     (Some(sender), Some(receiver)) -> {
//       // Verify sender's new balance
//       get_token_balance(sender) == datum.amount - amount &&
//       // Verify receiver receives the tokens
//       get_token_balance(receiver) >= amount
//     }
//     _ -> false
//   }
// }

// // Get token balance from output
// fn get_token_balance(output: Output) -> Int {
//   // Extract token balance from output value
//   // This depends on how you structure your token UTxOs
//   output.value |> value.get(#"token_asset_name", output.value)
// }

// // Check if token involved in transfer is registered
// fn token_is_registered_in_transfer(
//   reference_inputs: List<Input>,
//   token_address: Address
// ) -> Bool {
//   reference_inputs
//     |> list.any(fn(input) {
//         when input.output.datum {
//           InlineDatum(
//             RegistryNode {
//               tokenPolicy: _,
//               nextTokenPolicy: _,
//               transferLogicScript: script_hash,
//               userStateManagerHash: _,
//               globalStateUnit: _
//             }
//           ) -> {
//             // Check if this transfer validator matches a registered token's transfer logic
//             script_hash == hash_validator_address(token_address)
//           }
//           _ -> false
//         }
//       })
// }