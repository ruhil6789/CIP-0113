// ============================================================================
// transferLogic.ak - Token-specific Withdraw Script
// ============================================================================
// This is a WITHDRAW validator that implements custom transfer rules
// It's called by programmableLogicBase when a Transfer redeemer is used

use aiken/collection/list
use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/address.{
  Address, Credential, Script, VerificationKey as VKeyCredential,
}
use cardano/assets.{AssetName, PolicyId, Value, quantity_of}
use cardano/script_context.{ScriptContext}
use cardano/transaction.{
  Datum, InlineDatum, Input, Output, OutputReference, Transaction, ValidityRange,
}

// ============================================================================
// Types (Must match programmableLogicBase.ak)
// ============================================================================
// owner: Hash<Blake2b_224, VerificationKey>,

/// User state attached to programmable tokens
pub type UserState {
  owner: Hash<Blake2b_224, VerificationKey>,
  customData: Data,
  isLocked: Bool,
  expiryTime: Option<Int>,
}

/// Transfer rules configuration for this specific token
pub type TransferConfig {
  /// Token policy ID this logic applies to
  tokenPolicy: PolicyId,
  /// Minimum transfer amount
  minTransferAmount: Int,
  /// Maximum transfer amount per transaction
  maxTransferAmount: Int,
  /// Whitelist of allowed recipient addresses (empty = anyone)
  allowedRecipients: List<Address>,
  /// Whether transfers require sender signature
  requireSenderSignature: Bool,
  /// Cooldown period between transfers (in milliseconds)
  transferCooldown: Int,
}

/// Redeemer passed to the withdraw script
pub type TransferRedeemer {
  /// Reference to the input being spent from programmableLogicBase
  spentInputRef: OutputReference,
  /// Recipient address
  recipient: Address,
  /// Amount being transferred
  amount: Int,
  /// Asset name
  assetName: ByteArray,
  /// Optional proof data for custom validation
  transferProof: Option<Data>,
}

// ============================================================================
// Main Validator: TransferLogic (Withdraw Script)
// ============================================================================

/// Token-specific withdraw script implementing custom transfer rules
/// This script is invoked via "withdraw 0" pattern by programmableLogicBase
validator transfer_logic(config: TransferConfig) {
  withdraw(
    redeemer: TransferRedeemer,
    stake_credential: Credential,
    ctx: ScriptContext,
  ) {
    let ScriptContext { transaction, .. } = ctx
    let Transaction { inputs, outputs, extra_signatories, validity_range, .. } =
      transaction

    // Verify this is the correct stake credential
    expect Script(script_hash) = stake_credential

    let TransferRedeemer {
      spentInputRef,
      recipient,
      amount,
      assetName,
      transferProof,
    } = redeemer

    // 1. Find the input being spent from programmableLogicBase
    expect Some(spent_input) =
      inputs |> list.find(fn(input) { input.output_reference == spentInputRef })

    // 2. Extract user state from spent input
    expect InlineDatum(data) = spent_input.output.datum
    expect user_state: UserState = data

    // 3. Validate all transfer rules
    expect validate_amount_limits(amount, config)
    expect validate_recipient(recipient, config)
    expect
      validate_sender_signature(user_state.owner, extra_signatories, config)
    expect validate_transfer_cooldown(user_state, validity_range, config)
    expect
      validate_token_presence(
        spent_input.output.value,
        config.tokenPolicy,
        assetName,
        amount,
      )
    expect
      validate_recipient_output(
        outputs,
        recipient,
        config.tokenPolicy,
        assetName,
        amount,
      )
    expect validate_custom_transfer_rules(user_state, transferProof, config)

    True
  }

  else(_) {
    fail
  }
}

// ============================================================================
// Validation Functions
// ============================================================================

/// Validate transfer amount is within configured limits
fn validate_amount_limits(amount: Int, config: TransferConfig) -> Bool {
  amount >= config.minTransferAmount && amount <= config.maxTransferAmount && amount > 0
}

/// Validate recipient is allowed (if whitelist is configured)
fn validate_recipient(recipient: Address, config: TransferConfig) -> Bool {
  if list.length(config.allowedRecipients) == 0 {
    True
  } else {
    list.has(config.allowedRecipients, recipient)
  }
}

/// Validate sender signature is present (if required)
fn validate_sender_signature(
  owner: Hash<Blake2b_224, VerificationKey>,
  signatories: List<Hash<Blake2b_224, VerificationKey>>,
  config: TransferConfig,
) -> Bool {
  if config.requireSenderSignature {
    list.has(signatories, owner)
  } else {
    True
  }
}

/// Validate transfer cooldown period
fn validate_transfer_cooldown(
  user_state: UserState,
  validity_range: ValidityRange,
  config: TransferConfig,
) -> Bool {
  if config.transferCooldown > 0 {
    // Extract last transfer time from customData
    // This requires parsing customData which is token-specific
    // For now, return True as placeholder
    True
  } else {
    True
  }
}

/// Validate the spent input contains the token being transferred
fn validate_token_presence(
  value: Value,
  policy: PolicyId,
  assetName: AssetName,
  expected_amount: Int,
) -> Bool {
  let actual_amount = quantity_of(value, policy, assetName)
  actual_amount >= expected_amount
}

/// Validate recipient output receives the tokens with proper user state
fn validate_recipient_output(
  outputs: List<Output>,
  recipient: Address,
  policy: PolicyId,
  assetName: AssetName,
  expected_amount: Int,
) -> Bool {
  outputs
    |> list.any(
        fn(output) {
          let Output { address, value, datum, .. } = output
          address == recipient && quantity_of(value, policy, assetName) >= expected_amount && validate_recipient_state(
            datum,
            recipient,
          )
        },
      )
}

/// Validate recipient output has proper user state
fn validate_recipient_state(datum: Datum, recipient: Address) -> Bool {
  when datum is {
    InlineDatum(data) -> {
      expect user_state: UserState = data
      when recipient.payment_credential is {
        VKeyCredential(vkey_hash) ->
          user_state.owner == vkey_hash && !user_state.isLocked
        _ -> True
      }
    }
    _ -> False
  }
}

/// Validate custom transfer rules (extensible)
fn validate_custom_transfer_rules(
  user_state: UserState,
  transferProof: Option<Data>,
  config: TransferConfig,
) -> Bool {
  when transferProof is {
    Some(proof) -> validate_transfer_proof(proof, user_state)
    None -> True
  }
}

/// Validate transfer proof (placeholder for custom logic)
fn validate_transfer_proof(proof: Data, user_state: UserState) -> Bool {
  // Implement custom proof validation:
  // - Merkle proofs for whitelist
  // - Signature verification
  // - Oracle data validation
  True
}

// ============================================================================
// Third-Party Transfer Logic (Admin Actions)
// ============================================================================

/// Admin action types
pub type AdminAction {
  Lock
  Unlock
  UpdateMetadata { newData: Data }
  ForceTransfer { recipient: Address, amount: Int, assetName: AssetName }
}

/// Admin configuration
pub type AdminConfig {
  tokenPolicy: PolicyId,
  adminKeys: List<Hash<Blake2b_224, VerificationKey>>,
  canForceTransfer: Bool,
}

/// Admin redeemer for third-party transfers
pub type AdminRedeemer {
  action: AdminAction,
  targetInputRef: OutputReference,
}

/// Third-party transfer logic for admin actions (separate withdraw script)
validator third_party_transfer_logic(config: AdminConfig) {
  withdraw(
    redeemer: AdminRedeemer,
    stake_credential: Credential,
    ctx: ScriptContext,
  ) {
    let ScriptContext { transaction, .. } = ctx
    let Transaction { inputs, outputs, extra_signatories, .. } = transaction

    expect Script(script_hash) = stake_credential

    let AdminRedeemer { action, targetInputRef } = redeemer

    // 1. Verify admin signature
    expect validate_admin_signature(extra_signatories, config.adminKeys)

    // 2. Find target input being spent
    expect Some(target_input) =
      inputs
        |> list.find(fn(input) { input.output_reference == targetInputRef })

    // 3. Extract user state
    expect InlineDatum(data) = target_input.output.datum
    expect user_state: UserState = data

    // 4. Validate admin action
    validate_admin_action(action, target_input, outputs, user_state, config)
  }

  else(_) {
    fail
  }
}

/// Validate admin signature is present
fn validate_admin_signature(
  signatories: List<Hash<Blake2b_224, VerificationKey>>,
  adminKeys: List<Hash<Blake2b_224, VerificationKey>>,
) -> Bool {
  adminKeys |> list.any(fn(admin_key) { list.has(signatories, admin_key) })
}

/// Validate admin action
fn validate_admin_action(
  action: AdminAction,
  target_input: Input,
  outputs: List<Output>,
  user_state: UserState,
  config: AdminConfig,
) -> Bool {
  when action is {
    Lock ->
      validate_state_update(
        outputs,
        target_input.output.address,
        UserState { ..user_state, isLocked: True },
      )
    Unlock ->
      validate_state_update(
        outputs,
        target_input.output.address,
        UserState { ..user_state, isLocked: False },
      )
    UpdateMetadata { newData } ->
      validate_state_update(
        outputs,
        target_input.output.address,
        UserState { ..user_state, customData: newData },
      )
    ForceTransfer { recipient, amount, assetName } -> {
      expect config.canForceTransfer
      validate_recipient_output(
        outputs,
        recipient,
        config.tokenPolicy,
        assetName,
        amount,
      )
    }
  }
}

/// Validate state is properly updated in outputs
fn validate_state_update(
  outputs: List<Output>,
  address: Address,
  expected_state: UserState,
) -> Bool {
  outputs
    |> list.any(
        fn(output) {
          output.address == address && when output.datum is {
            InlineDatum(data) -> {
              expect output_state: UserState = data
              output_state.owner == expected_state.owner && output_state.customData == expected_state.customData && output_state.isLocked == expected_state.isLocked && output_state.expiryTime == expected_state.expiryTime
            }
            _ -> False
          }
        },
      )
}
