# 9. Photo sharing is a separate AI setting

Date: 2026-11-10 · Status: proposed

## Context
Testers want the coach to look at photos: a piece they're thinking of buying,
or themselves wearing an item (fit, body type, colouring). The AI client
already carries images (`AiMessage.images`), so the open question is consent,
not plumbing. Product rule 4 says to send the least the AI needs, and photos
of a person are the most sensitive thing the app could send.

## Decision
- A separate switch in AI settings, **"Let the AI see photos"**, off by
  default. Turning AI on does not turn it on.
- When off, every photo control in AI screens is hidden, per rule 1.
- When on, photos are still sent only when the user attaches one to a
  message. The app never attaches wardrobe photos on its own. Features that
  are about a photo ("fill in from photo", coach attachments) are the only
  senders.
- Photos of the user wearing something are sent under the same switch, but
  the body and fit profile keeps its own switch (see the roadmap). Photos
  don't override it.
- The setting's help text says photos go to the chosen provider and may be
  stored by it, and that the model must support images (many local models
  don't). A failed image request shows a clear message, not a generic error.
- Photos are downscaled and re-encoded as JPEG before sending, to cut cost
  and drop metadata such as GPS.

## Consequences
- One more field on `AiSettings` (stored with the other AI settings, not in
  the database).
- Users on text-only models keep a working coach.
- Coach threads that contain photos store them locally with the thread so
  old threads stay readable. They count towards backup size.
- A later "Archive thread" feature will let the user either delete a
  thread's photos or keep downscaled copies, to reclaim space.
- The AI on/off switch is on the main Settings screen and the provider setup
  is on the AI settings screen. This switch and future AI options go on the
  AI settings screen, and the on/off switch moves there too.
