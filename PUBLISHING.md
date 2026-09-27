# Taterland publishing steps

The v1.0.3 browser build is a release candidate for playtesting. It is not a
Steam submission. Spudions rename the existing game currency; balances,
prices and save data retain their values.

## 1. Get the release and test a fresh farm

1. Open https://github.com/CourseMain/Taterwake/releases/tag/v1.0.3.
2. Under **Assets**, download `Taterland-Web.zip` for the packaged browser build,
   or use https://coursemain.github.io/Taterwake/.
3. Keep your existing save. Use a separate browser profile for a fresh test farm.
4. Ask 5–10 people to play without coaching. Watch their first planting,
   harvest and sale, tool and land purchases, a build perk, island travel,
   and recovery from debt. Record where they stop or get confused.
5. Fix blockers before setting a commercial release date. Check an existing
   save as well as a fresh farm after every save-related fix.

## 2. Choose the intended audience

The current Roll House includes stakes, losses and chance-based payouts.
Australia classifies games containing simulated gambling R18+. Roblox
prohibits playable simulated gambling. Renaming dollars to Spudions does
not change the underlying mechanic or settle its classification.

For a broad farming-game audience, the recommended design change is to
replace wagering with skill challenges or quest-earned artifact rewards.
If retaining the Roll House, assess its classification and disclose it
accurately before deciding which territories and audiences to support.

Sources: [Australian Classification](https://www.classification.gov.au/about-us/media-and-news/news/new-classifications-for-gambling-content-video-games),
[Roblox Community Standards](https://about.roblox.com/community-standards).

## 3. Open Steamworks and register the game

1. Go to https://partner.steamgames.com/steamdirect and sign in with the
   account that will publish Taterland.
2. Complete the publisher agreement, identity verification, bank details and
   tax interview using the publisher's accurate legal information.
3. Pay the Steam Direct fee: US$100 per product, with applicable taxes.
   It is recoupable after US$1,000 adjusted gross revenue; it is not an
   ordinary refundable deposit.
4. Record the new game's **App ID**. This identifies the Steam project and
   is needed when configuring and uploading its builds.

Steam's current onboarding page lists at least 21 days after the app-fee payment for the first releases and a
public Coming Soon page for at least two weeks. These periods can overlap.
Allow additional time for review and fixes.

Sources: [Steam onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding),
[Steam Direct fee](https://partner.steamgames.com/doc/gettingstarted/appfee).

## 4. Prepare the store page

1. Open the game's Steamworks landing page, then **Edit Store Page**.
2. Add a short description, supported languages and only features the build
   actually supports. Prepare capsule artwork, clear gameplay screenshots
   and a short gameplay trailer using Steam's current asset specifications.
3. Complete the Content Survey accurately, including gambling-like content
   and any AI-generated player-facing art, sound or narrative. AI assistance
   with development tools is not by itself the focus of that section.
4. Confirm rights and required attribution for artwork, sounds, music and
   fonts. Keep the existing bundled engine/font notices.
5. Complete the store-page checklist and submit it for review. After
   approval, publish the page as **Coming Soon** and start collecting
   wishlists. This does not release the paid game.

Sources: [Store page](https://partner.steamgames.com/doc/store),
[Graphical assets](https://partner.steamgames.com/doc/store/assets),
[Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey).

## 5. Prepare and test a desktop build

1. Start with Windows. In Godot, open **Project → Export**, add a
   **Windows Desktop** preset and install matching export templates if asked.
2. Export a release build into a new build folder. Keep all required files
   together. The browser ZIP is not the intended Windows Steam executable.
3. Test on an actual Windows machine: install/launch, input, sound, window
   resizing, graphics settings, save/reload and an uninterrupted farming run.
4. In Steamworks, configure the Windows depot and launch executable, then
   upload through SteamPipe using the game's App ID and Depot ID.
5. Put the build on a private testing branch. Install it through Steam and
   repeat the launch/save checks. Claim macOS, Linux, controller or Steam
   Deck support only after testing those targets.

Sources: [Godot Windows export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html),
[SteamPipe](https://partner.steamgames.com/doc/sdk/uploading).

## 6. Review, price and release

1. Choose a one-time purchase price after playtesting the game's length and
   quality. US$4.99–7.99 is a provisional design suggestion, not a revenue
   estimate. Configure and review regional prices in Steamworks.
2. Complete the build checklist and submit the release build for review.
   Fix any review findings and test the resulting build again.
3. When review, waiting periods and our own launch checks are complete, use
   Steamworks' release controls on the chosen date. Steam approval alone
   does not automatically publish the game.
4. Keep save-compatible patches and clear release notes ready after launch.

Source: [Steam release process](https://partner.steamgames.com/doc/store/releasing).

An itch.io demo or playtest is optional alongside this process. Roblox would
require a separate implementation in Roblox Studio and changes to the
current Roll House, so it is not the recommended next port.
