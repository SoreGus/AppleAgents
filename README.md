# AppleAgents

AppleAgents is a demonstration app for **AppleAgentKit** that shows how a single Apple-platform application can work with three model execution strategies:

- **Apple Native** — Apple system models and Private Cloud Compute when available.
- **Remote** — remote providers, initially OpenAI.
- **Local** — downloadable models prepared for local execution with Core AI.

The app is intentionally lightweight. Model execution, local model management, Hugging Face integration, downloads, and runtime behavior belong to **AppleAgentKit**. AppleAgents focuses on configuration, model selection, UI, and a simple chat experience.

## Features

### Apple Native

When supported by the current device and application configuration, AppleAgents can expose Apple-native model options such as:

- System model
- Private Cloud Compute

Native options are shown only when they are actually available. Unsupported options should not appear in the UI.

> Private Cloud Compute requires the managed entitlement `com.apple.developer.private-cloud-compute` and approval from Apple.

### Remote

The initial remote provider is **OpenAI**.

The app supports:

- OpenAI API key configuration
- Remote model selection
- Secure API key storage in Keychain
- Chat through the selected remote model

For lightweight testing, `gpt-5-nano` is a suitable model choice.

### Local

Local models are distributed through the **Hugging Face Hub** and executed through the local runtime supported by AppleAgentKit.

The app supports:

- Embedded local-model catalog
- Model compatibility checks
- Download and installation
- Numeric download progress
- Visual progress indicator
- Background download support when available
- Cancellation
- Removal
- Update detection
- Local model selection
- Core AI execution

The user does not need to manage repository URLs or local file paths manually.

## Architecture

```text
AppleAgents
    |
    +-- UI / Navigation
    +-- Model Selection
    +-- Settings
    +-- Keychain Credentials
    +-- Local Model Catalog
    +-- Chat
            |
            v
      AppleAgentKit
            |
     +------+------+------+
     |             |      |
   Native        Remote  Local
     |             |      |
FoundationModels  OpenAI  Hugging Face
                         |
                       Core AI
```

AppleAgents is a **consumer of AppleAgentKit**. It should not duplicate responsibilities already implemented by the package.

## Model Flow

### Native

```text
AppleAgents
    -> AppleAgentKit / FoundationModels
    -> Apple Native Model
    -> LanguageModelSession
```

### Remote

```text
AppleAgents
    -> OpenAI configuration
    -> AppleAgentKit
    -> OpenAILanguageModel
    -> LanguageModelSession
```

### Local

```text
local-models.json
    -> Local Models UI
    -> AppleAgentKit
    -> Hugging Face
    -> Download / Installation
    -> CoreAILanguageModel
    -> LanguageModelSession
```

All model types ultimately converge on the same session-oriented architecture used by the app.

## Project Structure

A typical structure is:

```text
AppleAgents/
├── Models/
├── Services/
├── ViewModels/
├── Views/
│   ├── Chat/
│   ├── Models/
│   ├── Settings/
│   └── Components/
├── Resources/
│   └── local-models.json
├── ContentView.swift
└── AppleAgentsApp.swift
```

## Local Model Catalog

Supported local models are declared in `local-models.json`.

The catalog describes what the app can offer for installation. The real installation state is provided by AppleAgentKit.

Typical metadata includes:

```json
{
  "id": "qwen3-coreai",
  "name": "Qwen3 CoreAI",
  "repository": "owner/repository",
  "revision": "main",
  "runtime": "coreAI",
  "supportedPlatforms": ["macOS"],
  "supportedArchitectures": ["arm64"]
}
```

The catalog should remain controlled and limited to models verified for the app.

## Download Progress

During local-model downloads, the UI can show:

```text
Qwen3 CoreAI

Downloading...
682 MB / 935 MB
73%

[██████████████------]

Cancel
```

Progress data comes from AppleAgentKit. AppleAgents is responsible only for presenting it.

## Configuration

### OpenAI

1. Open **Settings**.
2. Select or enter the OpenAI model ID.
3. Add an API key.
4. Save the configuration.
5. Select the OpenAI model in the Models screen.

API keys are stored in **Keychain** and must never be persisted in `UserDefaults`, plist files, JSON files, or source code.

### Local Models

1. Open **Models**.
2. Choose a compatible local model.
3. Start the download.
4. Monitor installation progress.
5. Select the model after installation.
6. Return to Chat and start a conversation.

### Apple Native

Native models appear only when the current device and application configuration support them.

Private Cloud Compute additionally requires Apple approval for the managed PCC entitlement.

## Chat

The chat is intentionally simple. Its purpose is to validate the currently selected model through a common interface.

The UI displays the active model and sends new messages through the corresponding `LanguageModelSession`.

Changing the selected model prepares the appropriate session for subsequent requests.

## Security

- Store remote API keys only in Keychain.
- Do not log credentials.
- Do not persist secrets in project files.
- Delegate model storage and installation paths to AppleAgentKit.
- Keep model compatibility checks aligned with the runtime requirements.

## Dependencies

The project uses AppleAgentKit and its model/runtime dependencies, including the libraries required for Foundation Models, Core AI, Hugging Face, and local model execution.

Dependencies should already be resolved by the Xcode project.

## Requirements

Exact platform requirements depend on the AppleAgentKit version, selected model runtime, and Apple APIs used by the project.

Local Core AI models may have their own minimum OS, platform, and architecture requirements.

Private Cloud Compute requires a managed entitlement granted by Apple.

## Purpose

AppleAgents is designed as a practical reference implementation for **AppleAgentKit**, demonstrating how Apple-platform apps can switch between:

- native Apple models,
- remote models,
- and locally downloaded models,

while keeping the application layer small and delegating model infrastructure to AppleAgentKit.
