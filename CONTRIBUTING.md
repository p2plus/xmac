# Contributing

PRs and issues are welcome. This is a small unofficial macOS shell around x.com.

- macOS 14+, Swift 5.9. `swift test`, then `./build.sh`.
- Keep the app a shell. Login and the timeline stay on x.com.
- Do not add scraping, cookie theft, private WebKit calls, or a claim that this is official.
- UI strings live in `Resources/*.lproj` for en, de, fr, es, ja, ko, and zh-Hans. Add every new string to all seven.
- The disk cache should stay small. Don't persist media "for later".
- Don't persist tokens, and don't hand the X session to another app. See PRIVACY.md.
- File uploads go through the system open panel. Camera and microphone stay limited to x.com. Location stays off.
- A passkey sheet needs an application identifier and Apple's `com.apple.developer.web-browser.public-key-credential` entitlement. Ad-hoc signing cannot carry that entitlement: the process is killed on launch. Do not add it, and do not read the key.
- Match the tone of the README. Short, plain, no pitch deck.

If you open an issue, include the macOS version and what you clicked.
