# Golf Mat backend

Local API for Strike Lab: sessions, golfer profile, and clubhouse.

## Run

```bash
cd backend
npm install
npm run dev
```

Listens on [http://127.0.0.1:8787](http://127.0.0.1:8787).

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/health` | Liveness |
| GET/POST/DELETE | `/api/sessions` | Practice session history |
| GET/PUT | `/api/profile` | Golfer profile + computed stats |
| GET | `/api/clubhouse` | Leaderboard, challenges, feed, bulletin |
| POST | `/api/clubhouse/challenges/:id/join` | Join a challenge |
| POST | `/api/clubhouse/feed` | Post to the board |
| POST | `/api/clubhouse/feed/:id/like` | Like a post |

Data file: `backend/data/app.json` (created on first write).

## With the app

```bash
# terminal 1
cd backend && npm run dev

# terminal 2
cd swing-visualizer && npm run dev
```

Vite proxies `/api` → this server.
