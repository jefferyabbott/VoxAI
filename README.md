# VoxAI

A lightweight macOS utility that enables voice dictation anywhere with AI-powered text formatting. Simply hold the Fn key to dictate text, which will be automatically transcribed and pasted into your current application.

## Features

- **Quick Activation**: Hold the Fn key to start dictating, release to stop
- **Universal Compatibility**: Works in any text input field across all applications
- **AI-Powered Formatting**: Hold Shift+Fn to activate AI formatting that adapts to your current application
- **Context-Aware**: Automatically adjusts formatting based on the target application (email, messages, terminal, etc.)
- **Menu Bar Integration**: Unobtrusive menu bar icon shows recording status
- **On-Device Processing**: Speech recognition runs locally for privacy

## Requirements

- macOS 13.0 or later
- Microphone access permission
- Speech recognition permission
- [Groq API key](https://groq.com) for AI formatting features

## Installation

1. Download the latest release from the Releases page
2. Move VoxAI.app to your Applications folder
3. Launch the application
4. Grant necessary permissions when prompted:
   - Microphone access
   - Speech recognition access
   - Accessibility access (for paste functionality)

## Usage

1. Click the microphone icon in the menu bar to access settings
2. Hold the Fn key to start dictating
3. Speak clearly into your microphone
4. Release the Fn key to finish - text will be automatically pasted
5. Hold Shift+Fn while dictating to enable AI-powered formatting

### Formatting Modes

The app supports different formatting modes based on the current application:
- **Email**: Formats text with appropriate email structure
- **Messages**: Casual conversational formatting
- **Terminal**: Formats commands and paths appropriately
- **Default**: Standard text formatting

## Configuration

Access settings through the menu bar icon:
- Adjust formality level (casual, auto, formal)
- Customize email signature using casual and formal names
- Add your Groq API key

## Development

Built using:
- Swift
- macOS Speech Recognition Framework
- Groq API for AI text formatting

### Building from Source

1. Clone the repository
2. Open the project in Xcode
3. Build and run

## Privacy

- Speech recognition is performed locally on your device
- Audio is not stored or transmitted
- Only the transcribed text is sent to Groq for formatting when using Shift+Fn
- No usage data is collected

## License

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Acknowledgments

Created by Jeffery Abbott

- Built using Apple's Speech Recognition Framework
- AI formatting powered by Groq

Copyright (c) 2024 Jeffery Abbott
