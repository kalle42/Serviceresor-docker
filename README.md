# Serviceresor Docker

Dockerized live tracking for Serviceresor trips. Reads today's bookings, detects cancellations, and creates encrypted live map links. Links can be sent via 46elks SMS, TextBee, and/or ntfy. Maps expire after 60 minutes.

## Quick start

```bash
cp .env.example .env
# Edit .env with your credentials

docker compose build
docker compose up -d
```

Open `http://localhost:8787` and log in with the password from `.env`.

## Configuration

### Environment variables (`.env`)

| Variable | Required | Description |
|----------|----------|-------------|
| `ADMIN_DASHBOARD_PASSWORD` | Yes | Admin dashboard password (min 12 chars) |
| `HERENOW_API_KEY` | Yes | here.now API key |
| `HERENOW_PUBLISH_SCRIPT` | No | Path to publish.sh (default: `/app/tools/publish.sh`) |
| `ELKS_API_USERNAME` | No* | 46elks API username |
| `ELKS_API_PASSWORD` | No* | 46elks API password |
| `TEXTBEE_API_KEY` | No* | TextBee API key |
| `TEXTBEE_DEVICE_ID` | No | TextBee device ID |
| `NTFY_SERVER_URL` | No | ntfy server (default: `https://ntfy.sh`) |
| `NTFY_ACCESS_TOKEN` | No | ntfy access token |

*At least one notification channel (46elks, TextBee, or ntfy) must be configured per user.

### User credentials (`users.local.json`)

```bash
cp users.example.json users.local.json
# Edit with Serviceresor SSN/password and notification recipients
```

Mounts automatically via docker-compose volume.

## How it works

1. **5am daily** — cron runs the planner, fetches today's trips
2. **60 min before departure** — checks if trip is still booked
3. **10 min before departure** — starts tracking, creates live map
4. **During trip** — monitors vehicle position via browser automation
5. **60 min after departure** — map expires, session cleaned up

## Commands

```bash
docker compose up -d          # Start
docker compose down           # Stop
docker compose logs -f        # View logs
docker compose exec app bash  # Shell into container
```

## Architecture

```
entrypoint.sh           → starts cron + admin-server
├── cron (5am daily)    → run-daily-trips.sh
│   └── tracking-service.js (planner + tracker)
│       └── Chromium (headless, Puppeteer)
└── admin-server.js     → dashboard on :8787
    └── admin-dashboard/ (static UI)
```

## Security

- Never commit `.env`, `users.local.json`, or `.herenow/`
- Maps use OpenStreetMap with standard attribution and tile usage
- API keys are passed as environment variables, not baked into the image
- `users.local.json` is mounted read-only