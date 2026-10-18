# Contributing

PRs and issues are welcome. This is a small unofficial macOS shell around x.com.

- macOS 14+, Swift 5.9. `swift test`, then `./build.sh`.
- Keep the app a shell. Login and the timeline stay on x.com.
- Do not add scraping, cookie theft, private WebKit calls, or a claim that this is official.
- UI copy is English.
- The disk cache should stay small. Don't persist media "for later".
- Don't persist tokens, and don't hand the X session to another app. See PRIVACY.md.
- File uploads go through the system open panel. Camera and microphone stay limited to x.com. Location stays off.
- Match the tone of the README. Short, plain, no pitch deck.

If you open an issue, include the macOS version and what you clicked.
