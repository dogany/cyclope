//
//  UpdateService.swift
//  Cyclope
//

import Combine
import Foundation
import os
import Sparkle

@MainActor
final class UpdateService: NSObject, ObservableObject {
    @Published private(set) var canCheckForUpdates = true

    private static let automaticCheckInterval: TimeInterval = 24 * 60 * 60

    private let logger = Logger(subsystem: "com.dogany.cyclope", category: "UpdateService")
    private let updaterController: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?

    override init() {
        guard AppEnvironment.shouldRunBackgroundServices,
              Self.hasSparkleConfiguration else {
            updaterController = nil
            super.init()
            canCheckForUpdates = false
            return
        }

        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        super.init()
        configureAutomaticChecks()
        observeUpdateAvailability()
    }

    var currentVersionTitle: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""

        if build.isEmpty || build == version {
            return version
        }

        return "\(version) (\(build))"
    }

    func checkForUpdates() {
        guard let updaterController else {
            logger.warning("Sparkle update check skipped because configuration is missing.")
            return
        }

        updaterController.checkForUpdates(nil)
    }

    private func configureAutomaticChecks() {
        guard let updater = updaterController?.updater else { return }

        updater.automaticallyChecksForUpdates = true
        updater.updateCheckInterval = Self.automaticCheckInterval
    }

    private func observeUpdateAvailability() {
        guard let updater = updaterController?.updater else {
            canCheckForUpdates = false
            return
        }

        canCheckForUpdates = updater.canCheckForUpdates
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            let canCheckForUpdates = updater.canCheckForUpdates
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = canCheckForUpdates
            }
        }
    }

    private static var hasSparkleConfiguration: Bool {
        guard let feedURLString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              URL(string: feedURLString) != nil,
              let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
            return false
        }

        let trimmedKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedKey.isEmpty && !trimmedKey.contains("$(")
    }
}
