import Foundation

/// Rewrites Instagram's in-memory Instants seen set, a Swift `Set<String>` stored property.
/// Assigning through Swift keeps the native layout an NSSet written from ObjC would break.
@objc(SPKInstantsSeenStateBridge)
final class SPKInstantsSeenStateBridge: NSObject {
    /// Replaces the `Set<String>` stored at `address`, which the caller guarantees is a live
    /// `Set<String>` ivar used only on the main thread.
    @objc static func replaceStringSet(atAddress address: UnsafeMutableRawPointer, with values: [String]) {
        address.assumingMemoryBound(to: Set<String>.self).pointee = Set(values)
    }
}
