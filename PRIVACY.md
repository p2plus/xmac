# Privacy

The session stays in this app. Nothing here is a data feed you can export, and the app does not talk to a developer API.

- Sign-in cookies live in this app's WebKit store. Safari does not see them. This app does not see Safari's cookies.
- The password is typed into x.com. The app does not read it, store it, or send it anywhere else.
- This build cannot complete a passkey sign-in. macOS refuses the sheet because the ad-hoc signature has no application identifier. The app does not read, list, or send a passkey.
- The last page saved on disk is an x.com address with the token, code, and password fields removed. Half-finished login and account-repair pages are not saved.
- Copy Link and Open in Browser use that same cleaned address, and a token hidden in the address fragment is dropped too. The other app gets the link, not the session.
- Script messages are accepted only from the main page on x.com or twitter.com. A frame, a blank frame, or another site cannot push a notification into the app.
- Notification text is clipped. Control characters and bidi overrides are removed, and a page gets at most five banners a minute.
- Downloads land in Downloads under a cleaned file name — path pieces, controls, and direction overrides removed — and are not opened.
- Camera and microphone prompts are only started for x.com and twitter.com. CDN frames and any other site are denied. macOS asks before the device turns on.
- The file panel only opens for an upload that started on x.com or twitter.com.
- Location is denied. There is no location entitlement.
- The web inspector is off unless you launch with `XMAC_INSPECT=1`.
- Embedded frames inside a page can still load. That is the page, not the session, leaving the app.

Sign out in Settings deletes this app's website data. The account on x.com stays.
