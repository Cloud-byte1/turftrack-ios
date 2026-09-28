# Supabase setup for Strike Lab

I can’t create the account for you — you sign up, then we program against your project.

## 1. Create account + project

1. Open [supabase.com/dashboard/sign-up](https://supabase.com/dashboard/sign-up) (already opened in the browser).
2. Sign up with GitHub or email.
3. **New project** → pick org → name it `golf-mat` → set a DB password → Create.

## 2. Run the schema

1. Dashboard → **SQL Editor** → New query.
2. Paste everything from [`schema.sql`](./schema.sql).
3. Click **Run**.
4. Before shipping the iPhone app, run [`app_store_lockdown.sql`](./app_store_lockdown.sql)
   the same way. It adds the events table, removes the dev-open write policies, and
   routes profile edits, joins, likes, and RSVPs through narrow functions. After it,
   the publishable key cannot update or delete rows directly; deleting sessions from
   the backend needs `SUPABASE_SERVICE_ROLE_KEY`.
5. Then run [`auth_migration.sql`](./auth_migration.sql). It moves the iPhone app to
   Supabase Auth: every auth user gets a profile and leaderboard row (trigger on
   `auth.users`), sessions become private per golfer, feed posts are stamped with the
   author's `user_id`, challenge progress / RSVPs / likes are stored per golfer, and
   `delete_my_account()` removes a golfer and everything they own. Profiles are only
   readable when signed in, and `update_profile` is dropped, so the Express backend
   needs `SUPABASE_SERVICE_ROLE_KEY` to read or edit profiles after this step.

## 3. Copy API keys

1. **Project Settings → API**
2. Copy:
   - Project URL
   - `anon` `public` key
   - `service_role` key (server only — never put this in the Vite app)

## 4. Configure backend

```bash
cd backend
copy .env.example .env
```

Edit `.env`:

```env
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
PORT=8787
```

```bash
npm install
npm run dev
```

Health check should show `"storage":"supabase"`:

```bash
curl http://127.0.0.1:8787/api/health
```

Without `.env` keys, the API keeps using the local JSON file store.
