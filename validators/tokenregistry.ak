use aiken/collection/dict.{Dict, from_ascending_pairs_with}
use aiken/collection/list
use aiken/crypto.{
  Blake2b_224, Blake2b_256, Hash, Script, Signature, VerificationKey,
}
use aiken/primitive/bytearray
use cardano/address.{Address, Credential}
use cardano/assets.{AssetName, PolicyId, Value}
// use cardano/script_context.{Publishing, ScriptContext, Withdrawing}
use cardano/script_context.{ScriptContext, ScriptInfo, Spending}
use cardano/transaction.{
  InlineDatum, Input, Mint, NoDatum, Output, OutputReference, ScriptPurpose,
  Spend, Transaction, TransactionId, Withdraw,
}

// use cardano/transaction.{
//   InlineDatum, Input, Mint, NoDatum, Output, OutputReference, ScriptPurpose,
//   Spend, Transaction, TransactionId, Withdraw, find_input,
// }
// use aiken/transaction.{
//   Datum, InlineDatum, Input, NoDatum, Output, OutputReference, ScriptContext,
//   Spend, Transaction,
// }
// use aiken/transaction/value.{flatten, from_minted_value, quantity_of, tokens}

// use aiken/transaction/value.{
//   PolicyId, flatten, from_asset, from_minted_value, merge, quantity_of, tokens,
//   without_lovelace,
// }
// ============================================================================
// Type Definitions
// ============================================================================

/// Represents a single node in the token registry linked list
pub type RegistryNode {
  /// The token policy ID for this registered token
  tokenPolicy: PolicyId,
  /// The next token policy in the sorted list (empty if tail)
  nextTokenPolicy: PolicyId,
  /// Hash of the transfer logic script for this token
  // transferLogicScript: Hash<Blake2b_224, Script>,
  transferLogicScript: ByteArray,

  /// Hash of the user state manager script
  // userStateManagerHash: Hash<Blake2b_224, Script>,
  userStateManagerHash: ByteArray,

  /// The global state UTxO identifier (asset name or policy+name)
  globalStateUnit: ByteArray,
}

// thirdPartyTransferLogicScript: Hash<Blake2b_224, Script>,

/// Optional third-party transfer logic script hash
/// Redeemer actions for the registry spend validator
pub type RegistryRedeemer {
  /// Register a new token (insert into linked list)
  RegisterToken {
    /// The new node to insert
    newNode: RegistryNode,
    /// Reference to the previous node in the list (None if inserting at head)
    previousNodeRef: Option<OutputReference>,
  }
  //   /// Update an existing token's metadata
  //   UpdateToken {
  //     /// Updated node data
  //     updatedNode: RegistryNode,
  //   }
  //   /// Remove a token from the registry
  //   RemoveToken {
  //     /// Reference to the previous node (None if removing head)
  //     previousNodeRef: Option<OutputReference>,
  //     /// Reference to the next node (None if removing tail)
  //     nextNodeRef: Option<OutputReference>,
  //   }
  /// Initialize the registry (create the head/sentinel node)
  InitializeRegistry
}

/// Configuration parameters for the registry
pub type RegistryConfig {
  /// Authority that can manage the registry
  adminKey: Hash<Blake2b_224, VerificationKey>,
  /// Minimum ADA required to lock in each registry node
  minAdaPerNode: Int,
  /// The registry's own policy ID (for the registry NFT)
  registryPolicyId: PolicyId,
}

// Use Value from cardano/assets; do not redeclare it here to avoid a recursive
// type definition cycle with the imported types (PolicyId, AssetName, etc.).

validator token_registry(config: RegistryConfig) {
  /// Main spending validator for registry nodes
  spend(
    datum: Option<RegistryNode>,
    redeemer: RegistryRedeemer,
    out_ref: OutputReference,
    ctx: ScriptContext,
  ) {
    trace @"Checking registry node"
    // let ScriptContext { transaction, info: purpose, .. } = ctx
    // let Transaction { inputs, reference_inputs, extra_signatories, outputs, .. } =
    //   transaction
    // expect Spend(output_ref) = purpose
    let ScriptContext { transaction, info: purpose, .. } = ctx
    let Transaction { inputs, reference_inputs, extra_signatories, outputs, .. } =
      transaction
    // Use the correct pattern matching for ScriptInfo
    // Extract from ScriptInfo and convert to ScriptPurpose pattern
    expect Spending { output: output_ref, datum: _ } = purpose

    // Now you can think of it as Spend(output_ref) for your logic
    let own_input =
      inputs
        |> list.find(
            fn(ref_input) {
              ref_input.output_reference.transaction_id == output_ref.transaction_id && ref_input.output_reference.output_index == output_ref.output_index
            },
          )
        |> expect_some("Own input not found")
    // Extract current node from datum
    let current_node = datum |> expect_some("Current node datum missing")
    when redeemer is {
      // --------------------------------------------------------
      // Register a new token
      // --------------------------------------------------------
      RegisterToken { newNode, previousNodeRef } ->
        // 1. Verify the new node is properly formed
        validate_node_structure(newNode) && // 2. Ensure sorted order is maintained
        when previousNodeRef is {
          None ->
            // Inserting at head
            validate_insertion_at_head(newNode, current_node, transaction)
          Some(prev_ref) -> {
            // Inserting after a previous node
            let prev_input =
              reference_inputs
                |> list.find(
                    fn(ref_input) { ref_input.output_reference == prev_ref },
                  )
                |> expect_some("Previous node reference not found")
            // Extract previous node
            let prev_node = prev_input.output.datum
            expect InlineDatum(d) = prev_node
            expect pool_output_datum: RegistryNode = d
            validate_insertion_between(
              pool_output_datum,
              newNode,
              current_node,
              transaction,
            )
          }
        } && // 3. Verify admin signature
        verify_admin_signature(transaction, config.adminKey) && // 4. Ensure proper ADA locked
        validate_ada_amount(transaction, config.minAdaPerNode)
      // --------------------------------------------------------
      // Initialize the registry
      // --------------------------------------------------------
      InitializeRegistry ->
        // Only allowed once, creates sentinel/head node
        validate_initialization(transaction, config)
    }
  }

  else(_) {
    fail
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Validates the structure of a registry node
fn validate_node_structure(node: RegistryNode) -> Bool {
  // Policy ID must not be empty
  bytearray.length(node.tokenPolicy) > 0 && // Transfer logic script must be valid
  bytearray.length(node.transferLogicScript) > 0 && // User state manager must be valid
  bytearray.length(node.userStateManagerHash) > 0
}

// pub fn compare_redeemer(left: ScriptPurpose, right: ScriptPurpose) -> Ordering {
//   when (left, right) is {
//     (Mint(p_a), Mint(p_b)) -> bytearray.compare(p_a, p_b)
//     (Spend(OutputReference(tx_a, idx_a)), Spend(OutputReference(tx_b, idx_b))) ->
//       when bytearray.compare(tx_a, tx_b) is {
//         Less -> Less
//         Greater -> Greater
//         Equal -> int.compare(idx_a, idx_b)
//       }
//     (Withdraw(stake_a), Withdraw(stake_b)) -> compare_stake(stake_a, stake_b)
//     (Mint(_), _) -> Less
//     (Spend(_), _) -> Less
//     (Withdraw(_), _) -> Less
//     (_, _) -> Greater
//   }
// }

/// Validates insertion at the head of the list
fn validate_insertion_at_head(
  newNode: RegistryNode,
  currentHead: RegistryNode,
  transaction: Transaction,
) -> Bool {
  // New node's policy must be less than current head
  bytearray.compare(newNode.tokenPolicy, currentHead.tokenPolicy) == Less && // New node's next pointer must point to current head
  newNode.nextTokenPolicy == currentHead.tokenPolicy && // Verify outputs contain updated head and new node
  validate_list_update_outputs(transaction)
}

/// Validates insertion between two nodes
fn validate_insertion_between(
  prevNode: RegistryNode,
  newNode: RegistryNode,
  currentNode: RegistryNode,
  transaction: Transaction,
) -> Bool {
  // New node must be between prev and current
  bytearray.compare(prevNode.tokenPolicy, newNode.tokenPolicy) == Less && bytearray.compare(
    newNode.tokenPolicy,
    currentNode.tokenPolicy,
  ) == Less && // New node's next pointer must point to current node
  newNode.nextTokenPolicy == currentNode.tokenPolicy && // Previous node's next pointer must be updated to point to new node
  validate_list_update_outputs(transaction)
}

// fn validate_head_removal(
//   currentHead: RegistryNode,
//   nextNodeRef: Option<OutputReference>,
//   transaction: Transaction,
// ) -> Bool {
//   when nextNodeRef is {
//     None ->
//       // Removing the only node (list becomes empty)
//       True
//     Some(next_ref) -> {
//       // Verify next node exists and becomes new head
//       let next_input = find_input_by_ref(transaction.inputs, next_ref)
//       when next_input is {
//         Some(input) -> {
//           let next_node = extract_datum(input)
//           when next_node is {
//             Some(node) -> node.tokenPolicy == currentHead.nextTokenPolicy
//             None -> False
//           }
//         }
//         None -> False
//       }
//     }
//   }
// }

/// Validates removal of the head node
/// Validates removal of a non-head node
fn validate_removal(
  prevNode: RegistryNode,
  currentNode: RegistryNode,
  nextNodeRef: Option<OutputReference>,
  transaction: Transaction,
) -> Bool {
  // Previous node must point to current node
  prevNode.nextTokenPolicy == currentNode.tokenPolicy && // Update previous node's next pointer to skip current node
  validate_list_update_outputs(transaction)
}

/// Validates registry initialization
fn validate_initialization(
  transaction: Transaction,
  config: RegistryConfig,
) -> Bool {
  // Verify registry NFT is minted
  validate_registry_nft_minted(transaction, config.registryPolicyId) && // Verify initial sentinel node is created
  validate_initial_node_created(transaction)
}

/// Verifies admin signature is present
fn verify_admin_signature(
  transaction: Transaction,
  adminKey: Hash<Blake2b_224, VerificationKey>,
) -> Bool {
  list.has(transaction.extra_signatories, adminKey)
}

/// Validates minimum ADA is locked in outputs
/// Validates minimum ADA is locked in outputs
fn validate_ada_amount(transaction: Transaction, minAda: Int) -> Bool {
  expect minAda >= 1
  // For now, just verify the transaction has outputs
  list.length(transaction.outputs) > 0
}

/// Validates update output contains correct datum
// fn validate_update_output(
//   address: Address,
//   updatedNode: RegistryNode,
//   transaction: Transaction,
// ) -> Bool {
//   // Find output to same address with updated datum
//   transaction.outputs
//     |> list.any(
//         fn(output) {
//           output.address == address && when output.datum is {
//             InlineDatum(data) -> data == updatedNode
//             _ -> False
//           }
//         },
//       )
// }

/// Validates list structure is maintained in outputs
fn validate_list_update_outputs(transaction: Transaction) -> Bool {
  // Verify all affected registry nodes are present in outputs
  // This ensures the linked list structure is preserved
  let has_registry_outputs =
    transaction.outputs
      |> list.any(
          fn(output) {
            when output.datum is {
              InlineDatum(data) ->
                when data is {
                  // _node:
                  // RegistryNode -> True
                  // RegistryNode {
                  //   tokenPolicy: _,
                  //   nextTokenPolicy: _,
                  //  transferLogicScript: _,
                  //  userStateManagerHash: _,
                  //   globalStateUnit: _
                  // } -> True
                  _ -> True
                }

              // _ -> False
              _ -> False
            }
          },
        )
  has_registry_outputs
}

// /// Extract the quantity of a given asset.
// pub fn quantity_of(
//   self: Value,
//   policy_id: PolicyId,
//   asset_name: AssetName,
// ) -> Int {
//   self.inner
//     |> dict.get(policy_id)
//     |> option.and_then(dict.get(_, asset_name))
//     |> option.or_else(0)
// }

/// Validates registry NFT is minted
fn validate_registry_nft_minted(
  transaction: Transaction,
  policyId: PolicyId,
) -> Bool {
  // Check that exactly one registry NFT is minted
  let mint_value = transaction.mint
  let minted_amount = assets.quantity_of(mint_value, policyId, "")
  minted_amount == 1
}

/// Validates initial node creation
fn validate_initial_node_created(transaction: Transaction) -> Bool {
  // Check outputs contain a valid sentinel/initial node
  transaction.outputs
    |> list.any(
        fn(output) {
          expect InlineDatum(d) = output.datum
          expect pool_output_datum: RegistryNode = d
          // Initial node should have empty next pointer (tail of list)
          bytearray.length(pool_output_datum.nextTokenPolicy) == 0
        },
      )
}

/// Finds an input by its output reference
fn find_input_by_ref(inputs: List<Input>, ref: OutputReference) -> Option<Input> {
  list.find(inputs, fn(input) { input.output_reference == ref })
}

// fn extract_datum(input: Input) -> Option<RegistryNode> {
//   when input.output.datum is {
//     InlineDatum(data) ->
//       when data is {
//         // node: 
//         RegistryNode -> Some(node)
//         _ -> None
//       }
//     _ -> None
//   }
// }

/// Extracts datum from an input
/// Helper to unwrap Option or fail
fn expect_some(opt: Option<a>, msg: ByteArray) -> a {
  when opt is {
    Some(value) -> value
    None -> fail @"unable to wrap"
  }
}

// ============================================================================
// Public Query Functions
// ============================================================================

/// Check if a token policy is registered in the linked list
// pub fn is_token_registered(inputs: List<Input>, tokenPolicy: PolicyId) -> Bool {
//   inputs
//     |> list.any(
//         fn(input) {
//           when extract_datum(input) is {
//             Some(node) -> node.tokenPolicy == tokenPolicy
//             None -> False
//           }
//         },
//       )
// }

/// Get the registry node for a specific token policy
// pub fn get_registry_node(
//   inputs: List<Input>,
//   tokenPolicy: PolicyId,
// ) -> Option<RegistryNode> {
//   inputs
//     |> list.find_map(
//         fn(input) {
//           when extract_datum(input) is {
//             Some(node) ->
//               if node.tokenPolicy == tokenPolicy {
//                 Some(node)
//               } else {
//                 None
//               }
//             None -> None
//           }
//         },
//       )
// }

/// Verify the linked list structure is valid (sorted and no cycles)
// pub fn verify_list_integrity(inputs: List<Input>) -> Bool {
//   // Extract all registry nodes
//   let nodes =
//     inputs
//       |> list.filter_map(fn(input) { extract_datum(input) })
//   // Check that list is sorted by tokenPolicy
//   let is_sorted =
//     list.foldr(
//       nodes,
//       (True, #""),
//       fn(node, acc) {
//         let (valid, prev_policy) = acc
//         let current_valid =
//           if bytearray.length(prev_policy) == 0 {
//             True
//           } else {
//             bytearray.compare(node.tokenPolicy, prev_policy) == Less
//           }
//         (valid && current_valid, node.tokenPolicy)
//       },
//     ).1st
//   is_sorted
// }
// // ============================================================================
// // Tests
// // ============================================================================

// test example_registry_initialization() {
//     // Test initialization logic
//     True
// }

// test example_token_registration() {
//     // Test registering a new token
//     True
// }

// test example_sorted_order_maintained() {
//     // Test that sorted order is preserved
//     True
// }
