import SwiftUI

struct ToolActivityView: View {
    let toolName: String
    @State private var opacity: Double = 0.5

    private var label: String {
        switch toolName {
        case "read_file": "Reading memory…"
        case "write_file": "Updating memory…"
        case "list_files": "Browsing files…"
        case "delete_file": "Removing file…"
        case "create_directory": "Creating folder…"
        case "create_event": "Adding to Calendar…"
        case "list_events": "Checking Calendar…"
        case "delete_event": "Removing event…"
        case "create_reminder": "Creating reminder…"
        case "list_reminders": "Checking reminders…"
        case "complete_reminder": "Completing reminder…"
        case "delete_reminder": "Removing reminder…"
        case "web_search": "Searching the web…"
        case "fetch_url": "Fetching page…"
        case "execute_code": "Running code…"
        case "get_current_time": "Checking time…"
        case "get_user_info": "Loading profile…"
        default: "Working…"
        }
    }

    private var icon: String {
        switch toolName {
        case "read_file", "write_file", "list_files", "delete_file", "create_directory": "brain.head.profile"
        case "create_event", "list_events", "delete_event": "calendar"
        case "create_reminder", "list_reminders", "complete_reminder", "delete_reminder": "bell"
        case "web_search", "fetch_url": "globe"
        case "execute_code": "terminal"
        default: "gearshape"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ProgressView()
                .scaleEffect(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .adaptiveGlass(.regular, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(opacity)
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ToolActivityView(toolName: "read_file")
        ToolActivityView(toolName: "web_search")
        ToolActivityView(toolName: "create_event")
    }
    .padding()
}
