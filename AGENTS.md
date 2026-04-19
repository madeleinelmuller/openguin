# AGENTS.md — Openguin Project Log

**Every agent working on this codebase must read this file first**, before reading any other file or making any changes. This is the authoritative changelog and instruction set for AI agents on this project.

## Purpose

- Track significant architectural decisions, refactors, and feature additions
- Provide context that isn't obvious from the code
- Let future agents pick up where previous ones left off

## Format

Entries are in reverse chronological order. Agents add entries at the top. Users prefix notes with `[USER NOTE]`.

---

## Entries

### 2026-04-19 — Build fixes & navigation cleanup (claude-opus-4-7)

Fixed all build errors + warnings. Build is green for `generic/platform=iOS`.

**Fixes:**
- `OpenGuin/ViewModels/ChatViewModel.swift:167` — removed `withAnimation(.spring(...))` wrapper in `finalizeMessage`. ChatViewModel doesn't import SwiftUI, so `withAnimation` was unresolved. The per-word reveal already animates via `WordRevealModifier`'s `.animation(_:value: isRevealed)`, so the VM just flips `isRevealed` and the view layer animates. Also changed `var msg` → `let msg` and added a `store.update(conversation)` after the flip so the persisted copy reflects the revealed state. **Rule going forward: keep SwiftUI out of ViewModels — animation belongs in the view layer.**
- `OpenGuin/Views/Root/ContentView.swift:10` — renamed local `enum Tab` → `enum AppTab`. It collided with SwiftUI's iOS 18+ `Tab` struct used in `TabView { Tab(...) { ... } }`, which made the compiler resolve `Tab("Chat", ...)` to the enum and fail. **Rule going forward: don't name local types `Tab`, `Section`, `Group`, etc. — SwiftUI adds new top-level types each release.**
- `OpenGuin/Views/Onboarding/OnboardingPermissionsView.swift` + `OpenGuin/Views/Settings/PermissionsSettingsView.swift` — dropped deprecated `EKAuthorizationStatus.authorized` fallback; `.fullAccess` is the iOS 17+ canonical value and deployment target is iOS 18.
- `OpenGuin/Services/NotificationManager.swift:10` — silenced unused-result warning on `try? await requestAuthorization(...)` with `_ =`.

**No behavior changes** beyond the build-error and warning fixes above.

---

### 2026-04-18 — Complete rebuild (claude-sonnet-4-6)

**Fresh start from scratch.** The prior codebase was wiped. New architecture:

**Key architectural decisions:**

- **AsyncStream<StreamEvent>** for LLM streaming — replaces callback/Task nesting. ChatViewModel uses a clean `for await` tool loop in `runAgentLoop()`. Max 20 iterations.
- **ToolDispatcher actor** — central router. All tool calls go through `ToolDispatcher.execute(name:inputJSON:)`. Add new tools in `AgentTool+Definitions.swift` + `ToolDispatcher.swift`.
- **No SwiftData** — conversations persist as `Documents/conversations.json`. Memory stays as markdown files. No migration complexity.
- **iOS 26 Liquid Glass** — all glass effects behind `#available(iOS 26, *)` in `GlassTheme.swift`. Fallback is `.ultraThinMaterial`. Never use glass APIs without the availability check.
- **Message reveal animation** — `MessageRevealModifier` splits assistant text into words, each word animates with staggered opacity+blur+Y. Triggered by `ChatMessage.isRevealed` flag set 50ms after message appended.
- **Web search** — DuckDuckGo Instant Answer API, no API key needed. `fetch_url` strips HTML tags and returns first 3000 chars.
- **Code execution** — JavaScript runs via `JavaScriptCore.JSContext`. Python/shell scripts are saved to `workspace/scripts/` and the path returned to the agent.
- **Ollama** — shares OpenAI-compatible code path in `LLMAPIService`. Endpoint is configurable.
- **Onboarding** — 5-step flow behind `@AppStorage("hasCompletedOnboarding")`. Steps: Welcome → Name → Provider → Permissions → Complete.
- **Memory files** — `Documents/AgentMemory/`: SOUL.md, USER.md, MEMORY.md, notes/, workspace/.

**Critical files:**
- `OpenGuin/Services/SystemPromptBuilder.swift` — the entire agent system prompt lives here
- `OpenGuin/Models/AgentTool+Definitions.swift` — all tool definitions (name, description, schema)
- `OpenGuin/Services/ToolDispatcher.swift` — routes tool names to services
- `OpenGuin/ViewModels/ChatViewModel.swift` — the agent tool loop
- `OpenGuin/Services/LLMAPIService.swift` — streaming engine

**Assets preserved:** openguin layered SVG icon (`Assets.xcassets/openguin/`), AppIcon, AccentColor.

**Deployment target:** iOS 18.0, Swift 6.0, no external packages.

---

### [USER NOTE] 2026-04-18 — Maddie

Starting totally fresh. Keep the memory system feeling alive and personal. The SVG penguin layers should animate during loading — they're in two separate layers on purpose. Everything should feel polished and delightful.
