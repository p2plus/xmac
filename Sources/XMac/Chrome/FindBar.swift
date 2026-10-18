import SwiftUI

struct FindBar: View {
    @EnvironmentObject private var model: WebModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find on page", text: $model.findQuery)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit { model.performFind(forward: true) }
                .onExitCommand { model.dismissFind() }
            if !model.findStatus.isEmpty {
                Text(model.findStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Button {
                model.performFind(forward: false)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .help("Previous match")
            Button {
                model.performFind(forward: true)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .help("Next match")
            Button {
                model.dismissFind()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close")
        }
        .padding(8)
        .background(.bar)
        .onChange(of: model.findQuery) { _, _ in
            model.performFind(forward: true)
        }
        .onAppear { focused = true }
        .onExitCommand { model.dismissFind() }
    }
}
