import SwiftUI

/// Browse, reuse, and clear past interactions.
struct HistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.history.items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(appState.history.items) { item in
                        HistoryRow(item: item)
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Text("\(appState.history.items.count) saved")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    appState.history.clear()
                } label: {
                    Label("Clear All", systemImage: "trash")
                }
                .disabled(appState.history.items.isEmpty)
            }
            .padding(10)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36)).foregroundStyle(.secondary)
            Text("No history yet").font(.headline)
            Text("Your interactions with the assistant will appear here.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct HistoryRow: View {
    @EnvironmentObject var appState: AppState
    let item: HistoryItem
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 8) {
                if !item.selectedText.isEmpty {
                    labeled("Selected", item.selectedText)
                }
                if !item.prompt.isEmpty {
                    labeled("Prompt", item.prompt)
                }
                labeled("Response", item.response)
                HStack {
                    Button {
                        ClipboardService.copyToClipboard(item.response)
                    } label: {
                        Label("Copy Response", systemImage: "doc.on.doc")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        appState.history.delete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.action)
                    Text("·")
                    Text(item.model)
                    Text("·")
                    Text(item.date, style: .date)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func labeled(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
