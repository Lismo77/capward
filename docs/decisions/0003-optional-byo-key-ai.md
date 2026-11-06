# 3. Optional AI with the user's own key

Date: 2026-11-05 · Status: accepted

## Context
This follows the nutrition app Chompass, where barcode lookup and manual
search work without AI, and AI scanning is an opt-in convenience. Here, an
experienced dresser should be able to curate everything by hand, while
someone newer to fashion can lean on an AI coach.

## Decision
- AI is off by default and can be switched on in Settings.
- The user supplies a provider, base URL, model and key. We support two
  formats: Anthropic Messages and OpenAI-compatible chat completions. Between
  them they cover nearly every hosted provider plus local servers like Ollama.
- Every AI feature is a shortcut on top of a manual flow, never the only way
  to do something.

## Consequences
- No AI costs for the project. Users choose their own price and privacy
  trade-off, including fully local models.
- AI code must always handle "no client configured".
- F-Droid will likely tag the app "NonFreeNet". Supporting self-hosted
  models softens this.
