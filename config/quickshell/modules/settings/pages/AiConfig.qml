import QtQuick
import QtQuick.Layouts
import "../../../core"
import "../widgets"
import "../"

ColumnLayout {
    id: root

    spacing: DesignTokens.spacingLG
    Layout.fillWidth: true

    SettingsCard {
        title: "AI Provider & Model"
        description: "Configure conversational AI models and local or cloud LLM backends."
        iconGlyph: "\uf544"

        SettingsRow {
            title: "LLM Backend Provider"
            description: "Engine used for launcher copilot and desktop questions."
            iconGlyph: "\uf085"

            SettingsChoice {
                configKey: "ai.provider"
                options: [
                    { label: "Google Gemini", value: "gemini" },
                    { label: "Groq (Llama)", value: "groq" },
                    { label: "OpenAI", value: "openai" },
                    { label: "Local Ollama", value: "ollama" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Model Identifier"
            description: "Target model name (e.g. gemini-2.5-flash, llama-3.3-70b-versatile, qwen2.5:7b)."
            iconGlyph: "\uf12e"

            SettingsTextField {
                configKey: "ai.model"
                placeholderText: "gemini-2.5-flash"
                preferredWidth: 260
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "API Secret Key"
            description: "Authentication token for cloud AI providers (stored locally in config.json)."
            iconGlyph: "\uf084"

            SettingsTextField {
                configKey: "ai.apiKey"
                placeholderText: "sk-..."
                preferredWidth: 260
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Sampling Temperature"
            description: "Creativity randomness (lower = precise; higher = imaginative)."
            iconGlyph: "\uf2c9"

            SettingsSlider {
                configKey: "ai.temperature"
                from: 0.0
                to: 1.0
                stepSize: 0.05
                decimals: 2
                unit: "temp"
            }
        }
    }

    SettingsCard {
        title: "System Prompt Persona"
        description: "Behavioral instructions injected into AI assistant context."
        iconGlyph: "\uf075"

        SettingsRow {
            title: "Custom System Prompt"
            description: "Set concise desktop persona."
            iconGlyph: "\uf27b"

            SettingsTextField {
                configKey: "ai.systemPrompt"
                placeholderText: "You are a concise, helpful desktop assistant."
                preferredWidth: 320
            }
        }
    }

    SettingsCard {
        title: "Voice Dictation & Transcription"
        description: "Speech-to-text input using local or cloud Whisper models."
        iconGlyph: "\uf130"

        SettingsRow {
            title: "Enable Voice Input"
            description: "Hold microphone hotkey to speak search queries."
            iconGlyph: "\uf205"

            SettingsSwitch {
                configKey: "ai.voiceSearchEnabled"
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Speech Provider"
            description: "Transcription model engine."
            iconGlyph: "\uf026"

            SettingsChoice {
                configKey: "ai.voiceProvider"
                options: [
                    { label: "Local Whisper", value: "whisper" },
                    { label: "Groq Whisper API", value: "groq" }
                ]
            }
        }

        SettingsDivider {}

        SettingsRow {
            title: "Spoken Language"
            description: "Primary spoken language or automatic detection."
            iconGlyph: "\uf1ab"

            SettingsChoice {
                configKey: "ai.voiceLanguage"
                options: [
                    { label: "Auto-detect", value: "auto" },
                    { label: "English", value: "en" },
                    { label: "Português", value: "pt" }
                ]
            }
        }
    }
}
