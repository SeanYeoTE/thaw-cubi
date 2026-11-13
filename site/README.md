# Thaw showcase site

Static marketing site for the App Store listing: plain HTML and CSS, no build step. `.github/workflows/pages.yml` publishes this folder to GitHub Pages on every push to `main` that touches `site/`.

| Page | Use |
|---|---|
| `index.html` | Landing page |
| `privacy.html` | App Store Connect privacy policy URL |
| `support.html` | App Store Connect support URL |

## Before launch

- Both download buttons say "Coming soon to the App Store" (there's no listing yet). Once the app is live, replace them with Apple's official "Download on the App Store" badge (Apple's marketing resources site) linking to the `apps.apple.com` URL, and drop "coming soon" from the download section.
- Update "Last updated" in `privacy.html` whenever the policy changes.
- One-off setup: repo Settings › Pages › Source: **GitHub Actions**.

## Demo loops (`media/`)

Simulator recordings on iPhone 17 Pro with seeded sample data (no real data), default text size, status bar overridden to 9:41. 540×1174 H.264 at ~600 kbps, muted, under 1 MB each. `main.js` plays a loop only while it's on screen and never autoplays when Reduce Motion is on.

| File | Shows | Launch arguments |
|---|---|---|
| `freeze.mp4` | Adding a want, Cubi freezes it | `-thawFixture sprint1` |
| `cool.mp4` | Payday tab before payday: countdown, frozen Cubi, quick thaw | `-thawFixture sprint1 -thawTab payday` |
| `payday.mp4` | Payday review: Keep, Let go, Wait | `-thawFixture thawed -thawTab payday` |
| `saved.mp4` | Stats: saved total, chart, filters | `-thawFixture history -thawTab stats` |

To re-record: `xcrun simctl io booted recordVideo --codec=h264 out.mp4`, then trim and scale to 540 px wide with a fixed bitrate (AVFoundation's Medium export preset silently drops to 220×480, so don't use it). Each `.jpg` beside a clip is its poster frame.

## Preview locally

```bash
python3 -m http.server -d site 8000
```
