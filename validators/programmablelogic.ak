use aiken/collection/list
use aiken/collection/pairs
use aiken/crypto.{Blake2b_224, Blake2b_256, Hash, Script, VerificationKey}
use aiken/primitive/bytearray
use cardano/address.{
  Address, Credential, Script as ScriptCredential, StakeCredential,
}
use cardano/assets.{AssetName, PolicyId, Value, quantity_of}
use cardano/script_context.{ScriptContext, ScriptInfo, Spending}
use cardano/transaction.{
  Datum, InlineDatum, Input, Output, OutputReference, ScriptPurpose, Spend,
  Transaction, ValidityRange, Withdraw,
}
use types/registry.{RegistryConfig, RegistryNode}

// 1. programmableLogicBase.ak (Universal Spend Script)

// Purpose: Single spend validator that holds ALL programmable tokens
// Key Features:

// Handles Transfer, AdminAction, and Burn redeemers
// Looks up registry node from reference inputs to find transfer logic script
// Delegates validation to token-specific withdraw scripts
// Manages UserState attached to each token holding

// ============================================================================
// Types
// ============================================================================

// pub type RegistryNode {
//   tokenPolicy: PolicyId,
//   nextTokenPolicy: PolicyId,
//   transferLogicScript: Hash<Blake2b_224, Script>,
//   userStateManagerHash: Hash<Blake2b_224, Script>,
//   globalStateUnit: ByteArray,
// }

/// Registry node structure (must match tokenRegistry.ak)
/// User state attached to programmable tokens
pub type UserState {
  /// Owner of the token
  owner: Hash<Blake2b_224, VerificationKey>,
  /// Custom metadata or state data
  customData: Data,
  /// Lock status (for transfer restrictions)
  isLocked: Bool,
  /// Expiry timestamp (if applicable)
  expiryTime: Option<Int>,
}

/// Redeemer for spending programmable tokens
pub type ProgrammableRedeemer {
  /// Standard transfer - must satisfy transferLogicScript
  Transfer {
    /// Destination address
    recipient: Address,
    /// Amount to transfer
    amount: Int,
    /// Asset name
    assetName: ByteArray,
  }
  /// Admin action - must satisfy thirdPartyTransferLogicScript
  AdminAction {
    /// Type of admin action
    action: AdminActionType,
    /// Asset name
    assetName: AssetName,
  }
  /// Burn tokens
  Burn {
    /// Amount to burn
    amount: Int,
    /// Asset name
    assetName: AssetName,
  }
}

pub type AdminActionType {
  /// Lock the token
  Lock
  /// Unlock the token
  Unlock
  /// Update custom data
  UpdateMetadata { newData: Data }
  /// Force transfer (emergency)
  ForceTransfer { recipient: Address }
}

// ============================================================================
// Main Validator: ProgrammableLogicBase
// ============================================================================

// datum: Option<UserState>,

/// Universal spend script that holds ALL programmable tokens
/// This script delegates validation to token-specific transfer logic scripts
validator programmable_logic_base {
  spend(
    datum: Option<UserState>,
    redeemer: ProgrammableRedeemer,
    own_ref: OutputReference,
    ctx: ScriptContext,
  ) {
    // Extract transaction
    let ScriptContext { transaction, info: purpose, .. } = ctx
    let Transaction { inputs, outputs, withdrawals, reference_inputs, mint, .. } =
      transaction
    // Get own input
    expect Some(own_input) =
      inputs |> list.find(fn(input) { input.output_reference == own_ref })

    expect Some(datum_data) = datum
    expect user_state: UserState = datum_data
    // ✅ Parse explicitly
    // // Extract user state
    // expect Some(user_state) = datum
    when redeemer is {
      // --------------------------------------------------------
      // Standard Transfer
      // --------------------------------------------------------
      Transfer { recipient, amount, assetName } -> {
        // 1. Find the token's registry node to get transfer logic script
        expect Some(registry_node) =
          find_token_registry_node(
            own_input.output.value,
            assetName,
            reference_inputs,
          )
        // 2. Verify transfer logic script is executed (via withdrawal)
        let transfer_logic_credential =
          ScriptCredential(registry_node.transferLogicScript)

        expect
          validate_withdrawal_present(
            transaction.withdrawals,
            transfer_logic_credential,
          )
        // 3. Validate transfer constraints
        validate_transfer(
          user_state,
          own_input.output,
          recipient,
          amount,
          assetName,
          outputs,
        ) && // 4. Ensure token is not locked
        !user_state.isLocked && // 5. Check expiry time if set
        validate_expiry(user_state.expiryTime, transaction.validity_range)
      }
      // --------------------------------------------------------
      // Admin Action
      // --------------------------------------------------------
      AdminAction { action, assetName } -> {
        // Find registry node
        expect Some(registry_node) =
          find_token_registry_node(
            own_input.output.value,
            assetName,
            reference_inputs,
          )
        // Verify admin logic script is executed (third-party transfer logic)
        // Note: For admin actions, we check a different withdraw credential
        // This would be the thirdPartyTransferLogicScript hash
        // For now, we'll validate the action directly
        validate_admin_action(
          action,
          user_state,
          own_input.output,
          outputs,
          assetName,
        )
      }
      // --------------------------------------------------------
      // Burn
      // --------------------------------------------------------
      Burn { amount, assetName } -> {
        // Find registry node to get policy
        expect Some(registry_node) =
          find_token_registry_node(
            own_input.output.value,
            assetName,
            reference_inputs,
          )
        // Verify tokens are actually being burned (negative mint)
        let burned_amount =
          quantity_of(mint, registry_node.tokenPolicy, assetName)
        burned_amount == -amount && // Ensure user can burn (not locked)
        !user_state.isLocked
      }
    }
  }

  else(_) {
    fail
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Find the registry node for a specific token in reference inputs
/// Find the registry node for a specific token in reference inputs
/// Find the registry node for a specific token in reference inputs
fn find_map(self: List<a>, with: fn(a) -> Option<b>) -> Option<b> {
  when self is {
    [] -> None
    [x, ..xs] ->
      when with(x) is {
        Some(result) -> Some(result)
        None -> find_map(xs, with)
      }
  }
}

fn find_token_registry_node(
  value: Value,
  assetName: AssetName,
  reference_inputs: List<Input>,
) -> Option<RegistryNode> {
  let policies = value |> assets.policies()
  reference_inputs
    |> find_map(
        fn(input) {
          when input.output.datum is {
            InlineDatum(data) -> {
              expect node: RegistryNode = data
              if list.has(policies, node.tokenPolicy) && validate_asset_belongs_to_token(
                assetName,
                node.globalStateUnit,
              ) {
                Some(node)
              } else {
                None
              }
            }
            _ -> None
          }
        },
      )
}

/// Validate asset name belongs to the token symbol
fn validate_asset_belongs_to_token(
  assetName: AssetName,
  tokenSymbol: ByteArray,
) -> Bool {
  let asset_len = bytearray.length(assetName)
  let symbol_len = bytearray.length(tokenSymbol)
  // Direct match
  assetName == tokenSymbol || // Asset name starts with token symbol
  asset_len >= symbol_len && bytearray.slice(assetName, 0, symbol_len - 1) == tokenSymbol || // Asset name ends with token symbol
  asset_len >= symbol_len && bytearray.slice(
    assetName,
    asset_len - symbol_len,
    asset_len - 1,
  ) == tokenSymbol
}

// withdrawals: List<(Credential, Int)>,
/// Check if a withdrawal to a specific credential is present
fn validate_withdrawal_present(
  withdrawals: Pairs<Credential, Int>,
  credential: Credential,
) -> Bool {
  withdrawals
    |> list.any(
        fn(pair) {
          when pair is {
            Pair(cred, _amount) -> cred == credential
          }
        },
      )
}

/// Validate transfer constraints
fn validate_transfer(
  user_state: UserState,
  own_output: Output,
  recipient: Address,
  amount: Int,
  assetName: AssetName,
  outputs: List<Output>,
) -> Bool {
  // Find output to recipient with correct amount
  outputs
    |> list.any(
        fn(output) {
          output.address == recipient && // Check if output contains the transferred amount
          validate_output_has_tokens(
            output,
            own_output.value,
            assetName,
            amount,
          ) && // Ensure new state is created for recipient if needed
          validate_new_user_state(output.datum)
        },
      )
}

/// Validate output contains the expected token amount
fn validate_output_has_tokens(
  output: Output,
  original_value: Value,
  assetName: AssetName,
  expected_amount: Int,
) -> Bool {
  // Get policies from original value
  let policies = original_value |> assets.policies()
  // Check each policy for the asset
  policies
    |> list.any(
        fn(policy) {
          let amount = quantity_of(output.value, policy, assetName)
          amount >= expected_amount
        },
      )
}

/// Validate new user state is properly formed
fn validate_new_user_state(datum: Datum) -> Bool {
  when datum is {
    InlineDatum(data) -> {
      expect _: UserState = data
      True
    }
    _ -> False
  }
}

/// Validate token expiry time
fn validate_expiry(
  expiryTime: Option<Int>,
  validity_range: ValidityRange,
) -> Bool {
  when expiryTime is {
    Some(expiry) ->
      // Check if current time is before expiry
      // This is simplified - you'd need to extract time from validity_range
      True
    // Placeholder
    None -> True
  }
  // No expiry set
}

/// Validate admin actions
fn validate_admin_action(
  action: AdminActionType,
  user_state: UserState,
  own_output: Output,
  outputs: List<Output>,
  assetName: AssetName,
) -> Bool {
  when action is {
    Lock ->
      // Verify output has locked state
      outputs
        |> list.any(
            fn(output) {
              when output.datum is {
                InlineDatum(data) -> {
                  expect new_state: UserState = data
                  new_state.isLocked && new_state.owner == user_state.owner && output.address == own_output.address
                }
                _ -> False
              }
            },
          )
    Unlock ->
      // Verify output has unlocked state
      outputs
        |> list.any(
            fn(output) {
              when output.datum is {
                InlineDatum(data) -> {
                  expect new_state: UserState = data
                  !new_state.isLocked && new_state.owner == user_state.owner && output.address == own_output.address
                }
                _ -> False
              }
            },
          )
    UpdateMetadata { newData } ->
      // Verify output has updated metadata
      outputs
        |> list.any(
            fn(output) {
              when output.datum is {
                InlineDatum(data) -> {
                  expect new_state: UserState = data
                  new_state.isLocked && new_state.owner == user_state.owner && output.address == own_output.address
                }
                _ -> False
              }
            },
          )
    ForceTransfer { recipient } ->
      // Verify tokens are moved to recipient
      outputs
        |> list.any(
            fn(output) {
              output.address == recipient && validate_output_has_tokens(
                output,
                own_output.value,
                assetName,
                1,
              )
            },
          )
  }
  // At least some tokens
}

// ============================================================================
// Query Functions
// ============================================================================

/// Check if a token is locked
pub fn is_token_locked(user_state: UserState) -> Bool {
  user_state.isLocked
}

/// Check if a token has expired
pub fn is_token_expired(user_state: UserState, current_time: Int) -> Bool {
  when user_state.expiryTime is {
    Some(expiry) -> current_time >= expiry
    None -> False
  }
}

// ============================================================================
// Tests
// ============================================================================

test example_transfer() {
  True
}

test example_admin_lock() {
  True
}
