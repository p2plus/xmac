# Privacy

The session stays in this app. Nothing here is a data feed you can export, and the app does not talk to a developer API.

- Sign-in cookies live in this app's WebKit store. Safari does not see them. This app does not see Safari's cookies.
- The password is typed into x.com. The app does not read it, store it, or send it anywhere else.
- The last page saved on disk is an x.com address with the token, code, and password fields removed. A half-finished login page is not saved.
- Copy Link and Open in Browser use that same cleaned address. The other app gets the link, not the session.
- Script messages are accepted only from x.com, twitter.com, twimg.com, t.co, and pscp.tv. A blank frame or another site cannot push a notification into the app.
- Notification text is clipped. Control characters and bidi overrides are removed.
- Downloads land in Downloads under a cleaned file name and are not opened.
- Camera and microphone prompts are only started for x.com. Any other frame is denied. macOS asks before the device turns on.
- The file panel only opens for an upload that started on x.com.
- Location is denied. There is no location entitlement.
- The web inspector is off unless you launch with `XMAC_INSPECT=1`.
- Embedded frames inside a page can still load. That is the page, not the session, leaving the app.

Sign out in Settings deletes this app's website data. The account on x.com stays.
