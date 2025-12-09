// use aiken/primitive/bytearray
// use aiken/collection/list
// use aiken/crypto.{Blake2b_256, Blake2b_224,Hash,Script, Signature, VerificationKey}
// use cardano/transaction.{
//   Datum, InlineDatum, Input, NoDatum, Output, OutputReference, Spend,
//   Transaction
// }
// use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
// use cardano/address.{Address, Credential}
// use cardano/assets.{AssetName, PolicyId, Value}



// fn validate_insertion_at_head(newNode: RegistryNode, current_policy: PolicyId, outputs: List<Output>) -> Bool {
//     bytearray.compare(newNode.tokenPolicy, current_policy) == Less &&
//     newNode.nextTokenPolicy == current_policy &&
//     outputs_contain_node(outputs, newNode)
// }

// fn outputs_contain_node(outputs: List<Output>, node: RegistryNode) -> Bool {
//     outputs
//         |> list.any(fn(output) {
//             when output.datum is {
//                 Some(datum_data) -> {
//                     when datum_data is {
//                         RegistryNode { tokenPolicy, .. } -> tokenPolicy == node.tokenPolicy
//                         _ -> false
//                     }
//                 }
//                 None -> false
//             }
//         })
// }

// fn outputs_contain_node_by_policy(outputs: List<Output>, policy: PolicyId) -> Bool {
//     outputs
//         |> list.any(fn(output) {
//             when output.datum is {
//                 Some(datum_data) -> {
//                     when datum_data is {
//                         RegistryNode { tokenPolicy, .. } -> tokenPolicy == policy
//                         _ -> false
//                     }
//                 }
//                 None -> false
//             }
//         })
// }

// fn validate_node_structure(node: RegistryNode) -> Bool {
//     // Convert to bytearray and check length
//     let policy_bytes: ByteArray = node.tokenPolicy
//     let transfer_bytes: ByteArray = node.transferLogicScript  
//     let user_state_bytes: ByteArray = node.userStateManagerHash
    
//     bytearray.length(policy_bytes) > 0 &&
//     bytearray.length(transfer_bytes) > 0 &&
//     bytearray.length(user_state_bytes) > 0 &&
//     bytearray.length(node.globalStateUnit) > 0
// }

// fn token_exists(tokenPolicy: PolicyId, reference_inputs: List<Input>) -> Bool {
//     reference_inputs
//         |> list.any(fn(input) {
//             when input.output.datum is {
//                 Some(datum_data) -> {
//                     when datum_data is  {
//                         RegistryNode { tokenPolicy: existing_policy, .. } -> existing_policy == tokenPolicy
//                         _ -> false
//                     }
//                 }
//                 None -> false
//             }
//         })
// }

// fn verify_admin_signature(extra_signatories: List<Hash>, admin_pkh: Hash) -> Bool {
//     extra_signatories |> list.has(admin_pkh)
// }

// // fn validate_ada_amount(outputs: List<Output>, min_ada: Int) -> Bool {
// //     outputs
// //         |> list.all(fn(output) {
// //             output.value >= Value::lovelace(min_ada)
// //         })
// // }
// fn validate_ada_amount(outputs: List<Output>, min_ada: Int) -> Bool {
//     let min_value = Value { lovelace: min_ada }
//     outputs
//         |> list.all(fn(output) {
//             value.ge(output.value, min_value)
//         })
// }


// validator token_registry(config: RegistryConfig) {
//     /// Main spending validator for registry nodes
//     spend(
//         datum: Option<RegistryNode>,
//         redeemer: RegistryRedeemer,
//         ctx: ScriptContext
//     ) {
//         trace @"Checking registry node"
//         // Extract transaction info
//         let ScriptContext { transaction,info:purpose .. } = ctx
        
//          let Transaction {
//       reference_inputs,
//       extra_signatories,
//       validity_range,
//       withdrawals,
//       outputs,
//       ..
//     } = transaction
//         //   trace transaction
//         when purpose  is {
//              // trace (info)
//             Spend(OutputReference{transaction_id, output_index:0}) -> { 
//             // Get own input
//             let own_input = transaction.inputs // <-- 'transaction' is now the correct TxInfo record
//             |> list.find(fn(input) {
//                 input.output_id.transaction_id == .transaction_id &&
//                 input.output_id.output_index == out_ref.output_index
//             })
//             |> expect_some("Own input not found")
  
//                 when redeemer is {
//                     // --------------------------------------------------------
//                     // Register a new token
//                     // --------------------------------------------------------
//                     RegisterToken { newNode, previousNodeRef } -> {
//                         // 1. Verify the new node is properly formed
//                         validate_node_structure(newNode) &&
                        
//                         // 2. Ensure sorted order is maintained
//                         when previousNodeRef is {
//                             None -> {
//                                 // Inserting at head
//                                 let current_node = datum |> expect_some("Current node datum missing")
//                                 validate_insertion_at_head(newNode, current_node, transaction)
//                             }
//                             Some(prev_ref) -> {
//                                 // Inserting after a previous node
//                                 let prev_input = find_input_by_ref(transaction.inputs, prev_ref)
//                                     |> expect_some("Previous node not found")
//                                 let prev_node = extract_datum(prev_input) 
//                                     |> expect_some("Previous node datum missing")
//                                 let current_node = datum 
//                                     |> expect_some("Current node datum missing")
                                
//                                 validate_insertion_between(prev_node, newNode, current_node, transaction)
//                             }
//                         } &&
                        
//                         // 3. Verify admin signature
//                         verify_admin_signature(transaction, config.adminKey) &&
                        
//                         // 4. Ensure proper ADA locked
//                         validate_ada_amount(transaction, config.minAdaPerNode)
//                     }
                    
//                     // --------------------------------------------------------
//                     // Update existing token metadata
//                     // --------------------------------------------------------
//                     // UpdateToken { updatedNode } -> {
//                     //     let current_node = datum |> expect_some("Current node datum missing")
                        
//                     //     // 1. Policy ID cannot change (maintains list position)
//                     //     current_node.tokenPolicy == updatedNode.tokenPolicy &&
                        
//                     //     // 2. Next pointer cannot change (maintains list structure)
//                     //     current_node.nextTokenPolicy == updatedNode.nextTokenPolicy &&
                        
//                     //     // 3. Verify admin signature
//                     //     verify_admin_signature(transaction, config.adminKey) &&
                        
//                     //     // 4. Ensure output contains updated datum
//                     //     validate_update_output(own_input.output.address, updatedNode, transaction)
//                     // }
                    
//                     // // --------------------------------------------------------
//                     // // Remove a token from the registry
//                     // // --------------------------------------------------------
//                     // RemoveToken { previousNodeRef, nextNodeRef } -> {
//                     //     let current_node = datum |> expect_some("Current node datum missing")
                        
//                     //     when previousNodeRef is {
//                     //         None -> {
//                     //             // Removing head node
//                     //             validate_head_removal(current_node, nextNodeRef, transaction)
//                     //         }
//                     //         Some(prev_ref) -> {
//                     //             // Removing intermediate or tail node
//                     //             let prev_input = find_input_by_ref(transaction.inputs, prev_ref)
//                     //                 |> expect_some("Previous node not found")
//                     //             let prev_node = extract_datum(prev_input) 
//                     //                 |> expect_some("Previous node datum missing")
                                
//                     //             validate_removal(prev_node, current_node, nextNodeRef, transaction)
//                     //         }
//                     //     } &&
                        
//                     //     // Verify admin signature
//                     //     verify_admin_signature(transaction, config.adminKey)
//                     // }
                    
//                     // --------------------------------------------------------
//                     // Initialize the registry
//                     // --------------------------------------------------------
//                     InitializeRegistry -> {
//                         // Only allowed once, creates sentinel/head node
//                         validate_initialization(transaction, config)
//                     }
//                 }
//             }
//             _ -> False
//         }
//     }
// }


// test mint_registered_token() {
//   let registry_node = RegistryNode {
//     tokenPolicy: my_policy_id,
//     nextTokenPolicy: empty_policy,
//     transferLogicScript: transfer_validator_hash,
//     userStateManagerHash: state_manager_hash,
//     globalStateUnit: #"MYTOKEN"
//   }
  
//   // This should succeed - token is registered
//   mint_transaction
//     |> with_reference_input(registry_node_utxo)
//     |> with_mint(MintToken { token_symbol: #"MYTOKEN", amount: 1000 })
//     |> assert_validates(token_minting_policy)
// }


// pub type RegistryNode {
//   /// The token policy ID for this registered token
//   tokenPolicy: PolicyId,
//   /// The next token policy in the sorted list (empty if tail)
//   nextTokenPolicy: PolicyId,
//   /// Hash of the transfer logic script for this token
//   transferLogicScript: Hash<Blake2b_224, Script>,
//   /// Hash of the user state manager script
//   userStateManagerHash: Hash<Blake2b_224, Script>,
//   /// The global state UTxO identifier
//   globalStateUnit: ByteArray,
//   /// The asset name for this token
//   assetName: ByteArray,
//   /// Optional third-party transfer logic script hash
//   // thirdPartyTransferLogicScript: Hash<Blake2b_224, Script>,
// 
// }

// fn token_is_registered_with_policy(
//   token_symbol: ByteArray,
//   minting_policy_id: PolicyId,
//   asset_name: ByteArray,
//   reference_inputs: List<Input>
// ) -> Bool {
//   reference_inputs
//     |> list.any(fn(input) {
//         let datum = input.output.datum
//         expect InlineDatum(d) = datum
//         expect RegistryNode { 
//           tokenPolicy: registered_policy, 
//           globalStateUnit: registered_symbol,
//           assetName: registered_asset_name,
//           ..
//         } = d
        
//         registered_policy == minting_policy_id &&
//         registered_symbol == token_symbol &&
//         registered_asset_name == asset_name
//       })
// }
// validator token_registry(config: RegistryConfig) {
//   /// Main spending validator for registry nodes
//   spend(
//     datum: Option<RegistryNode>,
//     redeemer: RegistryRedeemer,
//     ctx: ScriptContext,
//   ) {
//     trace @"Checking registry node"
//     // CORRECT: ScriptContext has 'tx_info' and 'purpose' fields
//     let ScriptContext { transaction, info: purpose, .. } = ctx
//     let Transaction { inputs, reference_inputs, extra_signatories, outputs, .. } =
//       transaction
//     // let purpose: ScriptPurpose = info
//     // let scriptInfo=Script
//     when purpose is {
//       Spend(output_ref) -> {
//         // Get own input
//         // Get own input using the correct pattern matching
//         let own_input =
//           inputs
//             |> list.find(
//                 fn(ref_input) {
//                   ref_input.output_ref.transaction_id == out_ref.transaction_id && ref_input.output_ref.output_index == out_ref.output_index
//                 },
//               )
//             |> expect_some("Own input not found")
//         expect Spend(spent_utxo_reference) = purpose
//         expect Some(input) =
//           find_input(transaction.inputs, spent_utxo_reference)
//         //         Extract current node from datum
//         let current_node = datum |> expect_some("Current node datum missing")
//         when redeemer is {
//           // --------------------------------------------------------
//           // Register a new token
//           // --------------------------------------------------------
//           RegisterToken { newNode, previousNodeRef } ->
//             // 1. Verify the new node is properly formed
//             validate_node_structure(newNode) && // 2. Ensure sorted order is maintained
//             when previousNodeRef is {
//               None ->
//                 // Inserting at head
//                 validate_insertion_at_head(newNode, current_node, transaction)
//               Some(prev_ref) -> {
//                 // Inserting after a previous node
//                 let prev_input =
//                   reference_inputs
//                     |> list.find(
//                         fn(ref_input) { ref_input.output_reference == prev_ref },
//                       )
//                     |> expect_some("Previous node reference not found")
//                 // Try both approaches - one will work based on your Aiken version:
//                 // Approach 1: If output.datum is directly Datum
//                 let prev_node = prev_input.output.datum
//                 // let prev_node = extract_registry_node(prev_input.output.datum)
//                 // |> expect_some("Failed to extract RegistryNode from datum")
//                 // Approach 2: If output.datum is Option<Datum>  
//                 // let prev_node = prev_input.output.datum
//                 //     |> expect_some("Previous node datum missing")
//                 expect InlineDatum(d) = prev_node
//                 expect pool_output_datum: RegistryNode = d
//                 validate_insertion_between(
//                   pool_output_datum,
//                   newNode,
//                   current_node,
//                   transaction,
//                 )
//               }
//             } && // 3. Verify admin signature
//             verify_admin_signature(transaction, config.adminKey) && // 4. Ensure proper ADA locked
//             validate_ada_amount(transaction, config.minAdaPerNode)
//           // --------------------------------------------------------
//           // Initialize the registry
//           // --------------------------------------------------------
//           InitializeRegistry ->
//             // Only allowed once, creates sentinel/head node
//             validate_initialization(transaction, config)
//         }
//       }
//       _ -> false
//     }
//   }

//   else(_) {
//     fail
//   }
// }




// fn validate_mint_amount(
//   ctx: ScriptContext,
//   policy_id: PolicyId,
//   asset_name: ByteArray,
//   expected_amount: Int
// ) -> Bool {
//   let minted_value = ctx.transaction.mint
// //   let actual_amount = assets.get(asset_name, minted_value)
//   let actual_amount = assets.quantity_of(minted_value,policy_id,asset_name)

//   actual_amount == expected_amount &&
//   assets.policies(minted_value) == [policy_id]
// }

// validate_mint_amount
// fn token_is_registered_with_policy(
//   token_symbol: ByteArray,
//   minting_policy_id: PolicyId,
//   asset_name: ByteArray,
//   reference_inputs: List<Input>
// ) -> Bool {
//   reference_inputs
//     |> list.any(fn(input) {
//      let datum = input.output.datum
// expect InlineDatum(d) = datum
// expect RegistryNode { 
//   tokenPolicy: registered_policy, 
//   globalStateUnit: registered_symbol,
//   ..
// }: RegistryNode = d

// registered_policy == minting_policy_id &&
// registered_symbol == expected_symbol
//       })
// }


// Validate minting amount matches the redeemer
// fn validate_mint_amount(
//   ctx: ScriptContext, 
//   policy_id: PolicyId, 
//   token_symbol: ByteArray, 
//   expected_amount: Int
// ) -> Bool {
//   let minted_value = ctx.transaction.mint
//   let actual_amount = assets.get(token_symbol, minted_value)
//   actual_amount == expected_amount &&
//   // Ensure only this specific token is being minted
//   assets.policies(minted_value) == [policy_id]
// }

// Validate burn amount
// fn validate_burn_amount(
// ctx: ScriptContext,
// policy_id: PolicyId,
// //   token_symbol: ByteArray,
//   asset_name: ByteArray,

//   expected_amount: Int
// ) -> Bool {
//   let minted_value = ctx.transaction.mint
//   let actual_amount = assets.quantity_of(minted_value, policy_id, asset_name)
//   // Negative amount for burning
//   actual_amount == -expected_amount &&
//   assets.policies(minted_value) == [policy_id]
// }
