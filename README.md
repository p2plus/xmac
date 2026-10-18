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

email and password are the reliable sign-in. google and apple open a sign-in window, and a second one when the provider asks. the session stays in this app.

## what you can do

after you sign in, the page is x.com. home, explore, notifications, messages, bookmarks, lists, grok, profile, replies, and posts.

- photos and video upload through the system file panel. the panel only opens for x.com
- camera and microphone are only offered to x.com, for a video or a space. macos still asks you first
- video fullscreen works. videos do not autoplay unless you turn that off in settings
- alerts from the open page show as mac notifications while the app is running
- links that are not x open in your browser, with tokens stripped off the url

location is off. this app does not read it and does not pass it to x.com.

## what it does

- navigation on the left, right, top, or bottom. default is left. change it in settings
- light, dark, or system, plus a few chrome themes (standard, ledger, graphite, phosphor)
- data saver: videos do not autoplay, images can be blocked, refresh interval is yours
- disk cache is wiped on launch and every 15 minutes. cookies stay, so the login stays. the app itself is a small binary
- dock badge from titles like `(3) Home / X`
- downloads go to Downloads and are not opened for you
- `twitter://` and `xmac://` open here. `https://` links from other apps stay with the browser
- the web inspector is off. set `XMAC_INSPECT=1` if you are debugging

privacy details are in [PRIVACY.md](PRIVACY.md).

## contribute

try it yourself. issues and pull requests are welcome.

say what you clicked and what you expected. small patches are easier to take than a rewrite.

do not send changes that pretend this is an official client, scrape the site, or lift someone else's session.
