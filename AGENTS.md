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

### 2026-04-23 — PNG spinner + endpoint normalization + rebuilt provider UI (claude-opus-4-7)

User asked to:
1. Use the new image sequence as the loading spinner (uploaded to `~/openguin/loading/{load,finish}/*.png`)
2. Rebuild the UI for more intuitive provider/endpoint config
3. Auto-handle `/v1` on local-model endpoints — user should only type host + port

**Loading spinner — frame sequence:**
- Copied the two sequences into the app's synchronized group at `OpenGuin/Resources/Loading/`. Names flattened with prefixes (`load_0001.png` … `finish_0125.png`, 62 total) so they bundle cleanly with Xcode 16's `PBXFileSystemSynchronizedRootGroup` (no xcassets / no pbxproj edits needed — they land flat at the bundle root).
- `OpenGuin/Views/Components/LoadingPenguin.swift` — rewrote to play a discovered-at-init PNG sequence. `FrameSequence(prefix:)` scans `Bundle.main.urls(forResourcesWithExtension: "png", ...)` for matching files and sorts lexically, so dropping more frames into `Resources/Loading/` Just Works with no code change.
- **Loop-to-finish handoff (refined):** when `isAnimating` flips to false we don't snap mid-loop. Instead we set a `pendingFinish` flag and let the current `load_` iteration play to its last frame; *then* we swap to the `finish_` sequence, play it once, and hold the last frame. This matches how the frames were animated in After Effects / wherever (the last `load_` frame flows naturally into the first `finish_` frame). Any jump-cut would look bad.
- `CelebrationPenguin` triggers the finish sequence after a short delay. Public API of both types is unchanged, so existing call sites in `OnboardingWelcomeView`, `OnboardingCompleteView`, and `ThinkingBubbleView` keep working.
- Verified bundle copy: 62 PNGs present at `OpenGuin.app/{load,finish}_*.png` after build.

**Endpoint normalization — `/v1` is now automatic:**
- `OpenGuin/Models/LLMProvider.swift` — added `normalizedEndpoint(from:)` extension. Rules:
  - Empty → `defaultEndpoint`
  - No scheme → prepend `http://` for local providers (Ollama / LM Studio), `https://` for cloud
  - Strip any `/v1` or `/v1/...` the user pasted so we don't double it when we append `chatPath`
  - Strip trailing slashes
- Also added `hasCustomEndpoint` and `endpointHint` helpers for the UI so the "do I show the endpoint field?" decision lives on the enum, not in each view.
- `OpenGuin/Services/LLMAPIService.swift` — both Anthropic and OpenAI-compat branches now call `provider.normalizedEndpoint(from: config.endpoint)` and guard the `URL(string:)` — an invalid URL now yields `.invalidEndpoint` instead of crashing the force-unwrap.
- `OpenGuin/ViewModels/ChatViewModel.swift` — preflight endpoint validation normalizes first, so `localhost:11434` passes.
- Removed the `trimmingSuffix` String extension (dead code now).

**Rebuilt provider settings UI:**
- `OpenGuin/Views/Settings/ProviderSettingsView.swift` — reorganized around the user's mental model rather than the data model:
  - *Provider* section (segmented picker, unchanged)
  - *Server* section only shows for local providers, with live `→ http://host:port/v1/chat/completions` preview under the input so users see exactly what we'll hit
  - *Model* section uses a picker for cloud providers and a free-text field for local providers
  - *API Key* section has helpful placeholders (`sk-ant-…`, `sk-…`) and a footer about local storage
- Extracted two reusable components: `EndpointField` (normalized preview) and `ModelPickerOrField` (smart per-provider model input). Onboarding reuses both, so the onboarding + settings flows can't drift apart.
- `OpenGuin/Views/Onboarding/OnboardingProviderView.swift` — rewritten to use those shared components. Also added a "custom" fallback in the model picker for cloud providers: if the stored model isn't in the hardcoded list (e.g. a newer name), it's added as `<name> (custom)` so the Picker can still display it instead of showing blank.

**Verified:** `xcodebuild … build` → `** BUILD SUCCEEDED **`.

**Rules going forward:**
- Drop PNG resources into `OpenGuin/Resources/…` — the synchronized root group picks them up. No pbxproj edits required. Use flat filenames (no subdirs inside the bundle's flat root) so `UIImage(named:)` / `Bundle.main.urls(forResourcesWithExtension:...)` is predictable.
- Never force-unwrap `URL(string:)` for user-supplied endpoints. Always run them through `LLMProvider.normalizedEndpoint(from:)` first and guard the result.
- The `/v1` suffix is handled by `LLMProvider.chatPath`. Don't hardcode it anywhere else. If the user pastes it, `normalizedEndpoint` will strip it.
- Keep onboarding and settings views visually different but share their form *inputs*. Drift between them was a source of bugs (see LM Studio model field in the previous entry).

---

### 2026-04-23 — Provider config correctness + clearer errors (claude-sonnet-4-6)

Two rounds of fixes across provider/model plumbing, continuing from the prior session's model-changer/Liquid-Glass work.

**Round 1 (earlier this session, not previously logged):**
- `OpenGuin/Views/Settings/ProviderSettingsView.swift` — added missing **Model name** TextField under LM Studio. The VM exposed `vm.model` for LM Studio but no UI was bound to it, so the model was stuck at whatever was last stored. Same fix applied to the onboarding variant.
- `OpenGuin/Views/Onboarding/OnboardingProviderView.swift` — same missing LM Studio model field. Added Divider + Model-name row.
- `OpenGuin/Services/LLMAPIService.swift` — endpoint construction could double-slash (`http://host:1234/` + `/v1/chat/completions` → `//`). Added a private `trimmingSuffix("/")` String extension and used it for both Anthropic and OpenAI-compat URL builds.
- `OpenGuin/Services/LLMAPIService.swift` — OpenAI-compat request body was missing `max_tokens`. Added it so Ollama/LM Studio respect the configured limit.
- `OpenGuin/Views/Components/GlassTheme.swift` — `.clear` case used `.regular.tint(.clear)` which just tints regular glass; swapped to the real `glassEffect(.clear, in:)` Apple API. Verified against Apple Liquid Glass docs.
- `OpenGuin/Views/Chat/ChatInputBar.swift` — background was flat `.bar`; now uses `glassEffect(.regular, in: .rect)` on iOS 26+ with `.bar` fallback. Consistent with the rest of the app.

**Round 2 (this turn):**

- `OpenGuin/Services/SettingsManager.swift` — **per-provider model storage**. Previously, Anthropic and OpenAI shared a single `settings.model` UserDefaults key, so switching providers clobbered the other's selection. Added `anthropicModel` and `openAIModel` with one-time migration from the legacy `model` key (heuristic: prefix `claude` → Anthropic; prefix `gpt|o1|o3` → OpenAI). Also added `setActiveModel(_:for:)` companion to `activeModel(for:)`. Removed the old top-level `model` property.
- `OpenGuin/ViewModels/SettingsViewModel.swift` — simplified the `provider` setter: it used to force `model = provider.defaultModel` on every switch, which overwrote the stored per-provider selection. Now it just changes provider. The `model` getter/setter route through the new `activeModel(for:)` / `setActiveModel(_:for:)` API, so each provider keeps its own model.
- `OpenGuin/Services/LLMAPIService.swift` — **useful HTTP error messages**. Previously a 401 surfaced as "API error 401" with zero context. Now on non-200 responses we drain up to 2048 bytes of the body, try to pull a `.error.message` / `.message` / `.error` field out of JSON, and format per-status messages: 401/403 tells the user to check their API key, 404 suggests verifying the endpoint (key for Ollama/LM Studio users with wrong ports), 429 marks rate-limiting, 5xx marks server errors. New error case `httpErrorWithBody(Int, String, LLMProvider)` carries the context; old `httpError(Int)` kept for compatibility.
- `OpenGuin/Services/LLMAPIService.swift` — use `config.provider.chatPath` instead of hardcoded `/v1/messages` and `/v1/chat/completions`. The property was already defined on `LLMProvider`; it was dead code.
- `OpenGuin/ViewModels/ChatViewModel.swift` — **preflight config check** in `sendMessage`. Surfaces a friendly error *before* hitting the wire when: no model selected, API key required but missing, or endpoint invalid for local providers. Stops the "send → wait → cryptic 401" UX.
- Added `LLMError.missingAPIKey(LLMProvider)` case for completeness even though the preflight is currently a plain String; kept for future use.

**Verified:** `xcodebuild … build` → `** BUILD SUCCEEDED **`.

**Rules going forward:**
- Never share a single UserDefaults key between multiple providers — one key per `(provider, setting)` pair.
- Provider/model mutation in the VM should only touch what the user actually changed. Don't cascade resets (e.g. "changing provider also resets model") unless there's a concrete reason.
- When bubbling up HTTP errors, always drain enough body to give the user a next action. "API error 401" is not actionable.

---

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
