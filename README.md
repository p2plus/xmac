# X for Mac

x took their mac app out of the store. this puts x.com back in the dock.

unofficial. not affiliated with x corp. the timeline, messages, and sign-in are the real site in a web view. this app does not store your password. links that are not x open in your browser.

## build

macOS 14 or newer.

```bash
./build.sh --run
```

that writes `X.app` in this folder. to keep it:

```bash
cp -R X.app /Applications/
```

email and password are the reliable sign-in. google and apple open a second window when x asks for one.

## what it does

- navigation on the left, right, top, or bottom. default is left. change it in settings
- light, dark, or system, plus a few chrome themes (standard, ledger, graphite, phosphor)
- data saver: videos do not autoplay, images can be blocked, refresh interval is yours
- disk cache is wiped on launch and every 15 minutes. cookies stay, so the login stays. the app itself is a small binary
- dock badge from titles like `(3) Home / X`
- downloads go to Downloads and are not opened for you
- `twitter://` and `xmac://` open here. `https://` links from other apps stay with the browser

## contribute

try it yourself. issues and pull requests are welcome.

say what you clicked and what you expected. small patches are easier to take than a rewrite.

do not send changes that pretend this is an official client, scrape the site, or lift someone else's session.
