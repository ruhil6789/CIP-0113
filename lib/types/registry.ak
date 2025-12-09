
// Every entry in the tokenRegistry MUST have attached an inline datum following this standard type
// This datum is enforced by the execution of the tokenRegistry at registration.

// pub type RegistryNode {
//     tokenPolicy: ByteArray,
//     nextTokenPolicy: ByteArray, 
//     transferLogicScript: ByteArray,
//     userStateManagerHash: ByteArray,
//     globalStateUnit: ByteArray, 
//     thirdPartyTransferLogicScript: ByteArray
// }
use aiken/crypto.{
  Blake2b_224, Blake2b_256, Hash, Script, Signature, VerificationKey,
}
use cardano/assets.{AssetName, PolicyId, Value}
use aiken/primitive/bytearray

pub type RegistryNode {
  /// The token policy ID for this registered token
  tokenPolicy: PolicyId,
  /// The next token policy in the sorted list (empty if tail)
  nextTokenPolicy: PolicyId,
  /// Hash of the transfer logic script for this token
  transferLogicScript: Hash<Blake2b_224, Script>,
  // transferLogicScript: ByteArray,

  /// Hash of the user state manager script
  userStateManagerHash: Hash<Blake2b_224, Script>,
  // userStateManagerHash: ByteArray,

  /// The global state UTxO identifier (asset name or policy+name)
  globalStateUnit: ByteArray,
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