# Changelog

## 0.2.1

- Filter out automated audio briefings, daily podcasts, news digests, bulletins, and non-story roundups (e.g. Times of India Top News Audio Briefing).
- Added `NewsSearchClient.isEditorialDigestOrAudioBriefing(_:)` detection helper.

## 0.2.0

- 24-hour default news search duration with provider-specific modifiers (Google `when:24h`, Bing `qft=interval="7"`).
- Strict client-side date verification against publication cutoff.
- 6-hour default in-memory query cache via `NewsSearchCache` actor and `bypassCache` option.
- Configurable RSS news feed providers (`NewsRSSProvider.google`, `NewsRSSProvider.bing`) and unified `NewsSearchConfiguration`.
- Direct RSS feed discovery helpers: `feedURL(for:provider:duration:)` and `feedURLs(for:duration:providers:)`.

## 0.1.0

Initial release: independent Swift async feed client, injectable transport, source and binary products, deterministic tests, protected-main CI and version-driven publication.
