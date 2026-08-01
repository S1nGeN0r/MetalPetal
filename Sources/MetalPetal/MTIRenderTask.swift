//
//  MTIRenderTask.swift
//  MetalPetal
//

import Foundation
import Metal

/// Represents a GPU render task - i.e., commands in a command buffer.
public final class MTIRenderTask {
    private let commandBuffer: MTLCommandBuffer
    private let scheduledOrCompleted = DispatchSemaphore(value: 0)
    private let completed = DispatchSemaphore(value: 0)

    public init(commandBuffer: MTLCommandBuffer) {
        self.commandBuffer = commandBuffer
        commandBuffer.addScheduledHandler { [scheduledOrCompleted] _ in
            scheduledOrCompleted.signal()
        }
        commandBuffer.addCompletedHandler { [scheduledOrCompleted] _ in
            scheduledOrCompleted.signal()
        }
        commandBuffer.addCompletedHandler { [completed] _ in
            completed.signal()
        }
    }

    /// Status of the underlying command buffer.
    public var commandBufferStatus: MTLCommandBufferStatus {
        commandBuffer.status
    }

    /// Synchronously blocks execution until the task either completes or fails (with error).
    public func waitUntilCompleted() {
        commandBuffer.waitUntilCompleted()
    }

    /// Waits up to `timeout` seconds for the command buffer to complete.
    ///
    /// Returns `true` when execution completed successfully. Returns `false` when the timeout
    /// expires or the command buffer fails. Unlike `MTLCommandBuffer.waitUntilCompleted()`, this
    /// method cannot block indefinitely when GPU execution is interrupted while an app is inactive.
    public func waitUntilCompleted(timeout: TimeInterval) -> Bool {
        switch commandBuffer.status {
        case .completed:
            return commandBuffer.error == nil
        case .error:
            return false
        case .notEnqueued, .enqueued, .committed, .scheduled:
            break
        @unknown default:
            return false
        }
        guard completed.wait(timeout: .now() + max(timeout, 0)) == .success else {
            return false
        }
        return commandBuffer.status == .completed && commandBuffer.error == nil
    }

    /// Waits up to `timeout` seconds for the command buffer to be scheduled.
    ///
    /// Returns `true` when the command buffer is scheduled or has completed successfully. Returns
    /// `false` when the timeout expires or the command buffer fails before it is scheduled. Unlike
    /// `MTLCommandBuffer.waitUntilScheduled()`, this method cannot block indefinitely.
    public func waitUntilScheduled(timeout: TimeInterval) -> Bool {
        switch commandBuffer.status {
        case .scheduled, .completed:
            return commandBuffer.error == nil
        case .error:
            return false
        case .notEnqueued, .enqueued, .committed:
            break
        @unknown default:
            return false
        }
        guard scheduledOrCompleted.wait(timeout: .now() + max(timeout, 0)) == .success else {
            return false
        }
        switch commandBuffer.status {
        case .scheduled, .completed:
            return commandBuffer.error == nil
        case .notEnqueued, .enqueued, .committed, .error:
            return false
        @unknown default:
            return false
        }
    }

    /// If an error occurred during execution, the NSError may contain more details about the problem.
    public var error: Error? {
        commandBuffer.error
    }
}
