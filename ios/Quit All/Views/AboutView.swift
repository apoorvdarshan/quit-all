import StoreKit
import SwiftUI

// MARK: - About View
struct AboutView: View {
    @ObservedObject private var updateChecker = AppUpdateChecker.shared

    private let gold = Color(hex: "D4AF37")

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Version")
                            .font(.system(size: 15, weight: .medium, design: .serif))
                        Spacer()
                        Text(updateChecker.currentVersion)
                            .font(.system(size: 14, design: .serif))
                            .foregroundColor(gold.opacity(0.5))
                    }

                    Button {
                        handleUpdateTap()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(gold)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("App Update")
                                    .font(.system(size: 15, weight: .medium, design: .serif))
                                    .foregroundColor(.white)
                                Text(updateChecker.displayStatus)
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundColor(updateChecker.isUpdateAvailable ? gold : .white.opacity(0.4))
                            }

                            Spacer()
                            updateAccessory
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        requestAppReview()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "star.fill")
                                .foregroundColor(gold)
                            Text("Rate the App")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "star.circle")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: appShareURL) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(gold)
                            Text("Share the App")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }
                } header: {
                    Text("APP")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(gold.opacity(0.6))
                        .tracking(1.5)
                }
                .listRowBackground(Color(hex: "111111"))

                Section {
                    Link(destination: URL(string: "https://www.instagram.com/apoorvcodes/")!) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(gold)
                            Text("Follow on Instagram")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Text(verbatim: "@apoorvcodes")
                                .font(.system(size: 13, design: .serif))
                                .foregroundColor(gold.opacity(0.6))
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }

                    Link(destination: URL(string: "https://x.com/apoorvdarshan")!) {
                        HStack {
                            Image(systemName: "at")
                                .foregroundColor(gold)
                            Text("Follow on X")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Text(verbatim: "@apoorvdarshan")
                                .font(.system(size: 13, design: .serif))
                                .foregroundColor(gold.opacity(0.6))
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }
                } header: {
                    Text("SOCIAL")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(gold.opacity(0.6))
                        .tracking(1.5)
                }
                .listRowBackground(Color(hex: "111111"))

                Section {
                    Link(destination: URL(string: "https://www.producthunt.com/products/quit-all-break-every-habit")!) {
                        HStack {
                            Image(systemName: "hand.thumbsup.fill")
                                .foregroundColor(gold)
                            Text("Vote on Product Hunt")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }

                    Link(destination: URL(string: "mailto:ad13dtu@gmail.com")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(gold)
                            Text("Contact Us")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }
                } header: {
                    Text("SUPPORT")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(gold.opacity(0.6))
                        .tracking(1.5)
                }
                .listRowBackground(Color(hex: "111111"))

                Section {
                    Link(destination: URL(string: "https://quit-all.com/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(gold)
                            Text("Privacy Policy")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }

                    Link(destination: URL(string: "https://quit-all.com/terms")!) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(gold)
                            Text("Terms of Service")
                                .font(.system(size: 15, weight: .medium, design: .serif))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(gold.opacity(0.4))
                        }
                    }
                } header: {
                    Text("LEGAL")
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(gold.opacity(0.6))
                        .tracking(1.5)
                }
                .listRowBackground(Color(hex: "111111"))
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "080808"))
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await updateChecker.checkForUpdate()
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var updateAccessory: some View {
        if updateChecker.isChecking {
            ProgressView()
                .tint(gold)
        } else if updateChecker.isUpdateAvailable {
            Text("UPDATE")
                .font(.system(size: 10, weight: .bold, design: .serif))
                .foregroundColor(.black)
                .tracking(0.8)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(gold)
                .cornerRadius(10)
        } else {
            Image(systemName: "arrow.clockwise")
                .font(.caption)
                .foregroundColor(gold.opacity(0.4))
        }
    }

    private var appShareURL: URL {
        updateChecker.appStoreURL ?? URL(string: "https://quit-all.com")!
    }

    private func handleUpdateTap() {
        if updateChecker.isUpdateAvailable {
            updateChecker.openAppStore()
        } else {
            Task {
                await updateChecker.checkForUpdate(force: true)
            }
        }
    }

    private func requestAppReview() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        SKStoreReviewController.requestReview(in: windowScene)
    }
}
