# Agent Change History

This file tracks code changes made by the coding agent and the reason for each change.

## 2026-02-24

### Crash hardening for malformed endpoints
- Replaced force-unwrapped URL construction (`URL(string: ...)!`) in API services with guarded URL parsing.
- Why: avoid runtime aborts when endpoint strings are malformed and return actionable errors instead.

### Voice mode marked as experimental + two-way behavior
- Updated chat input voice label to explicitly show **Voice (Experimental)**.
- Added `VoiceConversationService` for speech recognition + text-to-speech loop.
- Added microphone button in chat input when voice mode is enabled.
- Model now speaks responses and automatically returns to listening for the next user utterance (turn-by-turn flow).
- Why: support conversational voice UX where user speaks, model responds by voice, and listening resumes.

### iOS privacy and local networking support for voice + LM Studio
- Added `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` in `Info.plist`.
- Added ATS exceptions for `localhost` and `127.0.0.1`.
- Why: prevent permission-related crashes and allow local HTTP endpoints used by LM Studio.

### LM Studio endpoint normalization
- Changed LM Studio default endpoint to `http://localhost:1234/api/v1/chat`.
- Added behind-the-scenes normalization so if endpoint does not end with `/completions`, the app appends it automatically.
- Why: LM Studio commonly exposes `/api/v1/chat`; app still needs a chat completions endpoint.
