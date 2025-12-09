

// Every entry in the tokenRegistry MUST have attached an inline datum following this standard type
// This datum is enforced by the execution of the tokenRegistry at registration.

pub type RegistryNode {
    tokenPolicy: ByteArray,
    nextTokenPolicy: ByteArray, 
    transferLogicScript: ByteArray,
    userStateManagerHash: ByteArray,
    globalStateUnit: ByteArray, 
    thirdPartyTransferLogicScript: ByteArray
}