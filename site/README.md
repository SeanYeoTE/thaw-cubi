# Thaw website

Static marketing site for Thaw: plain HTML and CSS with no build step. It is published to GitHub Pages at <https://seanyeote.github.io/thaw-cubi/> by `.github/workflows/pages.yml` on every push to `main` that changes `site/`.

| Page | Purpose |
|---|---|
| `index.html` | Landing page |
| `privacy.html` | Privacy policy (App Store Connect privacy policy URL) |
| `support.html` | Support and FAQ (App Store Connect support URL) |

`styles.css` holds the design tokens (taken from the app's `Theme.swift`) and all styling. `main.js` plays the demo loops only while they are on screen.

## Before launch

- The two download buttons read "Coming soon to the App Store". Once the app is live, replace them with Apple's official "Download on the App Store" badge linking to the `apps.apple.com` listing, and drop "coming soon" from the download section.
- Update "Last updated" in `privacy.html` whenever the policy changes.
- Use the published `privacy.html` and `support.html` URLs in App Store Connect.

## Demo loops

The clips in `media/` are simulator recordings on iPhone 17 Pro. They use the app's seeded sample data, so no real data appears. They were recorded at the default text size with the status bar set to 9:41. Each is 540×1174 H.264 at about 600 kbps, muted and under 1 MB, with a poster frame (`.jpg`) beside it. The loops never autoplay when Reduce Motion is on.

| File | Shows | Launch arguments |
|---|---|---|
| `saved.mp4` | Stats: saved total, chart, filters | `-thawFixture history -thawTab stats` |
| `freeze.mp4` | Adding a want; Cubi freezes it | `-thawFixture sprint1` |
| `cool.mp4` | Payday tab before payday: countdown, frozen Cubi, quick thaw | `-thawFixture sprint1 -thawTab payday` |
| `payday.mp4` | Payday review: Keep, Let go, Wait | `-thawFixture thawed -thawTab payday` |

To re-record, run `xcrun simctl io booted recordVideo --codec=h264 out.mp4`, then trim and scale to 540 px wide with a fixed bitrate. Don't use AVFoundation's Medium export preset: it silently drops the video to 220×480.

## Preview locally

```bash
python3 -m http.server -d site 8000
```

Then open <http://localhost:8000>.
