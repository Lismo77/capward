# 10. Rename the app to Gansey

Date: 2026-11-10 · Status: accepted

## Context
"Capward" was a working name. The app needed a final name before it was
posted anywhere to recruit testers. Changing the Android application id
later turns the new build into a separate app, so anyone with it installed
would have to move their data across with a backup.

Names checked and dropped:
- Wornwell: an existing Google Play capsule-wardrobe app.
- Wovenwell: a pending USPTO filing for the same word.
- Tenue: an AI wardrobe stylist with the same idea.
- Four-in-Hand and Pintuck: clothing brands.

Oftworn and Placket were the runners-up.

## Decision
- The app is called **Gansey**. A gansey is the traditional fisherman's
  jumper of Ireland and Britain, made to last for decades and mended rather
  than replaced. That suits an app about wearing what you own.
- Availability on 2026-11-10: no app on F-Droid or Google Play, no USPTO
  filing, and only unrelated GitHub repos.
- Renamed: the app label, Android `applicationId` and `namespace`
  (`io.github.lismo77.gansey`), the Dart package (`gansey`), the web title
  and manifest, the GitHub repo (`Lismo77/gansey`) and the Pages path
  (`/gansey/`).
- New backups are written as `gansey-backup`. Backups marked
  `capward-backup` still import.
- The on-device database file stays `capsule_wardrobe.db`. Nobody sees it,
  and renaming it could lose data.
- Feedback email: ganseyapp@gmail.com.

## Consequences
- Anyone with the old build gets a second app rather than an update. To
  keep their data, they export a backup in the old app, import it in the
  new one, then uninstall the old one. The API key has to be entered again,
  because it lives in the old app's keystore.
- GitHub redirects links to the old repo, but the old Pages address
  (`/capward/`) stops working. Web testers need the new link, and browser
  data may not carry over, so they should export a backup first.
