# OpenGuin

A native iOS application that brings intelligent conversational AI to your device with voice capabilities and persistent memory management.

## Features

- **Chat Interface**: Real-time conversation with multiple LLM providers
- **Voice Interaction**: Natural language input and text-to-speech output
- **Memory System**: Persistent storage and browsing of conversation history
- **Multiple LLM Providers**: Support for various language model APIs
- **TTS Engine**: Integrated Kitten TTS for natural voice synthesis
- **Settings Management**: Secure API key storage and provider configuration

## Architecture

### Project Structure

```
OpenGuin/
├── Models/              # Data models (ChatMessage, Conversation, AgentMemory)
├── Services/            # Core services (LLM API, TTS, Voice, Memory, Settings)
├── Views/               # SwiftUI views organized by feature
│   ├── Chat/           # Chat interface components
│   ├── Memory/         # Memory browser and file views
│   ├── Settings/       # Settings interface
│   └── Compatibility/  # Platform compatibility utilities
├── ViewModels/         # MVVM view state management
├── KittenTTSWeb/       # Web-based TTS implementation
└── Assets/             # App resources and icons
```

### Key Components

- **LLMAPIService**: Manages communication with language model APIs
- **KittenTTSService**: Handles text-to-speech conversion with ONNX runtime
- **VoiceConversationService**: Speech recognition and synthesis orchestration
- **SettingsManager**: Secure settings and credentials storage
- **MemoryManager**: Conversation history persistence
- **NotificationManager**: Local and push notifications

## Requirements

- iOS 26.0 or later
- Xcode 16.0 or later
- Swift 6.0 or later

## Development

### Getting Started

1. Clone the repository
2. Open `OpenGuin.xcodeproj` in Xcode
3. Configure API keys in the Settings tab
4. Build and run on a compatible device or simulator

### Dependencies

- SwiftUI (iOS native framework)
- WebKit (for TTS web view)
- ONNX Runtime (embedded)
- Speech framework (for voice input)
- AVFoundation (for audio)

## Building

```bash
xcodebuild -scheme OpenGuin -configuration Release
```

## License

[Add your license here]

## Contributing

[Add contribution guidelines here]
