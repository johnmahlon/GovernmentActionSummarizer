# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fetches presidential actions from the White House RSS feed, uses OpenAI GPT to generate neutral/unbiased summaries, and publishes results as an RSS feed (`actions_feed.xml`) and HTML page (`index.html`). Output is auto-committed and pushed to GitHub, where it's hosted at https://johnmahlon.me/GovernmentActionSummarizer/.

## Running the Application

```bash
node main.js           # Process feed once
./summarizebills       # git pull, backup feed, then run node main.js
```

No build step required. The app uses ES modules (`"type": "module"` in package.json).

## Environment

Requires `OPENAI_API_KEY` in a `.env` file at the project root.

## Architecture

All application logic lives in a single file: `main.js`. The data flow is:

1. **Load cache** from `cache.json` (previously processed items)
2. **Fetch** White House presidential actions RSS feed via `rss-parser`
3. **Filter** out items already in cache
4. **Process** each new item through OpenAI GPT — system prompt instructs it to produce neutral, factual JSON with `{title, summary, link}`
5. **Generate outputs** — `actions_feed.xml` (RSS via `rss` package) and `index.html` (static HTML)
6. **Persist** — write updated `cache.json`, git commit, git push

## Key Implementation Notes

- The model used is configured as `gpt-5-nano` — verify this is a valid model name if API calls fail.
- `cache.json` stores the last processed items as `[{title, summary, link}]` to avoid reprocessing.
- The `summarizebills` shell script backs up `actions_feed.xml` to `actions_feed.backup.xml` before running.
- The app is designed to run as a scheduled/cron job (2-3x per day).
