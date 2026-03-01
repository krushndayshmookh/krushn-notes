# krushn-notes

A personal notes + todo app with real-time sync across Apple devices and web.

- **Backend** — Express.js API deployed to Vercel
- **Web** — Quasar (Vue 3) SPA deployed to Vercel
- **Apple** — SwiftUI app for iOS, iPadOS, and macOS

---

## Prerequisites

- Node.js 18+
- A [Vercel](https://vercel.com) account
- A [MongoDB Atlas](https://cloud.mongodb.com) account (free tier is fine)
- A [Pusher](https://pusher.com) account (free tier: 200k messages/day)
- A [GitHub OAuth App](https://github.com/settings/developers) for login
- Xcode 15+ (for Apple targets)

---

## 1. GitHub OAuth App

1. Go to **GitHub → Settings → Developer settings → OAuth Apps → New OAuth App**
2. Fill in:
   - **Application name:** krushn-notes (or anything)
   - **Homepage URL:** `https://your-backend.vercel.app` (use `http://localhost:3000` for local dev)
   - **Authorization callback URL:** `https://your-backend.vercel.app/auth/github/callback`
     - For local dev: `http://localhost:3000/auth/github/callback`
3. Click **Register application**
4. Note your **Client ID**
5. Click **Generate a new client secret** — note it immediately (shown once)

You'll need:
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`

---

## 2. MongoDB Atlas

1. Go to [cloud.mongodb.com](https://cloud.mongodb.com) → **Create a free cluster** (M0 tier)
2. Under **Database Access**: create a user with **Read and Write** permissions — note the username/password
3. Under **Network Access**: add `0.0.0.0/0` (allow from anywhere — Vercel IPs are dynamic)
4. Under your cluster → **Connect → Drivers**: copy the connection string
   - It looks like: `mongodb+srv://<user>:<password>@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority`
   - Replace `<user>` and `<password>` with your database user credentials
   - Add a database name: `mongodb+srv://user:pass@cluster0.xxxxx.mongodb.net/krushn-notes?retryWrites=true&w=majority`

You'll need:
- `MONGODB_URI`

---

## 3. Pusher Channels

1. Go to [pusher.com](https://pusher.com) → **Sign up / Log in**
2. **Create a new app** → choose **Channels**
   - Name: `krushn-notes`
   - Cluster: pick closest to you (e.g. `us2`, `eu`, `ap1`, `ap2`, `ap3`)
   - Frontend: Vue.js / Vanilla JS
   - Backend: Node.js
3. Under your app → **App Keys**, note:
   - `app_id`
   - `key`
   - `secret`
   - `cluster`
4. Under **App Settings** → enable **Private channels** (this is free)

You'll need:
- `PUSHER_APP_ID`
- `PUSHER_KEY`
- `PUSHER_SECRET`
- `PUSHER_CLUSTER`

---

## 4. JWT Secret

Generate a strong random string for signing JWTs:

```bash
openssl rand -base64 48
```

You'll need:
- `JWT_SECRET`

---

## 5. Environment Files

### Backend — `backend/.env`

Create `backend/.env` (never commit this file):

```env
# MongoDB
MONGODB_URI=mongodb+srv://user:password@cluster0.xxxxx.mongodb.net/krushn-notes?retryWrites=true&w=majority

# GitHub OAuth
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret

# JWT
JWT_SECRET=your_random_jwt_secret_here

# URLs (update after deploying web)
WEB_URL=http://localhost:5173
API_URL=http://localhost:3000

# Pusher
PUSHER_APP_ID=your_pusher_app_id
PUSHER_KEY=your_pusher_key
PUSHER_SECRET=your_pusher_secret
PUSHER_CLUSTER=your_pusher_cluster
```

After deploying to Vercel, update `WEB_URL` to your web app's Vercel URL and `API_URL` to your backend's Vercel URL.

### Web — `web/.env`

Create `web/.env` (never commit this file):

```env
# Backend API (update after deploying backend)
VITE_API_URL=http://localhost:3000

# Pusher (public key and cluster are safe to expose)
VITE_PUSHER_KEY=your_pusher_key
VITE_PUSHER_CLUSTER=your_pusher_cluster
```

After deploying to Vercel, update `VITE_API_URL` to your backend's Vercel URL.

### Apple app — `apple/krushn-notes/Config.xcconfig`

The iOS/macOS app reads config from `apple/krushn-notes/Config.xcconfig` (not committed):

```
API_BASE_URL = https://your-backend.vercel.app
PUSHER_KEY = your_pusher_key
PUSHER_CLUSTER = your_pusher_cluster
```

For local development against a local backend, use your machine's local IP (e.g. `http://192.168.1.x:3000`) — the simulator can reach your Mac via this address.

---

## 6. Local Development

### Backend

```bash
cd backend
npm install
npm run dev   # starts on http://localhost:3000
```

### Web

```bash
cd web
npm install
npm run dev   # starts on http://localhost:5173 (or similar)
```

Open `http://localhost:5173` in your browser. Log in with GitHub.

---

## 7. Deploying to Vercel

### Backend

```bash
cd backend
vercel
# Follow prompts: link to project, set environment variables
```

Set all variables from `backend/.env` in **Vercel → Project → Settings → Environment Variables**.

Also update your **GitHub OAuth App**'s callback URL to:
`https://your-backend.vercel.app/auth/github/callback`

### Web

```bash
cd web
quasar build     # outputs to web/dist/spa
vercel dist/spa  # deploy the built output
```

Or configure Vercel to run `quasar build` as the build command with `dist/spa` as the output directory.

Set `VITE_API_URL`, `VITE_PUSHER_KEY`, `VITE_PUSHER_CLUSTER` in the web project's Vercel environment variables.

---

## 8. iOS / macOS App

See `apple/README.md` for Xcode setup instructions, including:
- Adding PusherSwift via Swift Package Manager
- Setting up the App Group for widget data sharing
- Configuring URL scheme (`krushnnotes://`) for OAuth callback
- Building and running on Simulator or device

---

## Project Structure

```
krushn-notes/
├── backend/
│   ├── api/
│   │   └── index.js          # Vercel entry + Express app
│   ├── src/
│   │   ├── models/           # Mongoose models (User, Folder, Note, TaskList, Task)
│   │   ├── routes/           # Express routers (auth, folders, notes, tasks, sync)
│   │   ├── middleware/        # JWT auth middleware
│   │   └── lib/              # Pusher helper
│   ├── vercel.json
│   └── package.json
├── web/
│   ├── src/
│   │   ├── boot/             # Axios + auth interceptor
│   │   ├── composables/      # useSync (Pusher + offline queue)
│   │   ├── db/               # Dexie.js IndexedDB schema
│   │   ├── pages/            # Login, Notes, Tasks pages
│   │   ├── stores/           # Pinia stores (auth, notes, tasks)
│   │   └── router/           # Vue Router routes
│   ├── quasar.config.js
│   ├── vercel.json
│   └── package.json
└── apple/
    ├── krushn-notes.xcodeproj
    └── krushn-notes/
        ├── Shared/           # Code shared across all targets
        │   ├── APIClient.swift
        │   ├── SyncManager.swift
        │   ├── PusherManager.swift
        │   ├── Models.swift
        │   └── MarkdownRenderer.swift
        ├── iOS/              # iOS + iPadOS views
        ├── macOS/            # macOS views + floating panel
        └── Widget/           # WidgetKit + App Intents
```
