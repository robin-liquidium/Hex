import Foundation
import SwiftUI

enum UpstreamCheckWindow {
  static let id = "upstream-check"
}

struct UpstreamCheckButton: View {
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Button("Check Upstream…") {
      openWindow(id: UpstreamCheckWindow.id)
    }
  }
}

struct UpstreamCheckView: View {
  @State private var phase: Phase = .loading

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      switch phase {
      case .loading:
        HStack(spacing: 12) {
          ProgressView()
          Text("Checking official Hex main…")
        }

      case .loaded(let comparison):
        comparisonView(comparison)

      case .failed(let message):
        Label("Couldn’t check upstream", systemImage: "exclamationmark.triangle")
          .font(.headline)
        Text(message)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }

      Divider()

      HStack {
        Button("Refresh") {
          Task { await checkUpstream() }
        }
        .disabled(isLoading)

        Spacer()

        Link("Open comparison on GitHub", destination: UpstreamComparison.webURL)
      }
    }
    .padding(20)
    .frame(width: 520, alignment: .leading)
    .task {
      await checkUpstream()
    }
  }

  @ViewBuilder
  private func comparisonView(_ comparison: UpstreamComparison) -> some View {
    if comparison.aheadBy == 0 {
      Label("Your fork includes the latest upstream changes", systemImage: "checkmark.circle.fill")
        .font(.headline)
        .foregroundStyle(.green)
      Text("kitlangton/Hex main has no commits that are missing from your fork.")
        .foregroundStyle(.secondary)
    } else {
      Label(
        "\(comparison.aheadBy) upstream \(comparison.aheadBy == 1 ? "commit is" : "commits are") available",
        systemImage: "arrow.down.circle.fill"
      )
      .font(.headline)

      Text("Review these before pulling or cherry-picking anything into the fork:")
        .foregroundStyle(.secondary)

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 10) {
          ForEach(comparison.commits.prefix(10)) { commit in
            Link(destination: commit.htmlURL) {
              VStack(alignment: .leading, spacing: 3) {
                Text(commit.title)
                  .foregroundStyle(.primary)
                Text(commit.shortSHA)
                  .font(.caption.monospaced())
                  .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
      }
      .frame(maxHeight: 280)

      if comparison.commits.count < comparison.aheadBy {
        Text("Showing \(comparison.commits.count) of \(comparison.aheadBy) commits. Open GitHub for the full comparison.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var isLoading: Bool {
    if case .loading = phase { return true }
    return false
  }

  @MainActor
  private func checkUpstream() async {
    phase = .loading

    do {
      var request = URLRequest(url: UpstreamComparison.apiURL)
      request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
      request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
      request.setValue("Hex-Robin-Fork", forHTTPHeaderField: "User-Agent")

      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
      else {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        throw UpstreamCheckError.httpStatus(status)
      }

      phase = .loaded(try JSONDecoder().decode(UpstreamComparison.self, from: data))
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  private enum Phase {
    case loading
    case loaded(UpstreamComparison)
    case failed(String)
  }
}

private struct UpstreamComparison: Decodable {
  static let apiURL = URL(
    string: "https://api.github.com/repos/kitlangton/Hex/compare/robin-liquidium:main...main"
  )!
  static let webURL = URL(
    string: "https://github.com/kitlangton/Hex/compare/robin-liquidium:main...main"
  )!

  let aheadBy: Int
  let commits: [UpstreamCommit]

  enum CodingKeys: String, CodingKey {
    case aheadBy = "ahead_by"
    case commits
  }
}

private struct UpstreamCommit: Decodable, Identifiable {
  let sha: String
  let commit: Details
  let htmlURL: URL

  var id: String { sha }
  var shortSHA: String { String(sha.prefix(7)) }
  var title: String {
    commit.message.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? commit.message
  }

  enum CodingKeys: String, CodingKey {
    case sha
    case commit
    case htmlURL = "html_url"
  }

  struct Details: Decodable {
    let message: String
  }
}

private enum UpstreamCheckError: LocalizedError {
  case httpStatus(Int)

  var errorDescription: String? {
    switch self {
    case .httpStatus(let status):
      "GitHub returned HTTP \(status). Try again in a moment."
    }
  }
}
