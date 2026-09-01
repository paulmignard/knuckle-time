# KnuckleAuth

Minimal OAuth proxy for Knuckle Time iOS app. Securely handles Harvest API credential exchange so `client_secret` never touches the mobile app.

## What It Does

Two endpoints, that's it:

| Endpoint | Purpose |
|----------|---------|
| `POST /auth/token` | Exchange authorization code for tokens |
| `POST /auth/refresh` | Refresh expired access tokens |
| `GET /health` | Health check for Railway |

## Local Development

```bash
# Set your secrets
export Harvest__ClientId="your-client-id"
export Harvest__ClientSecret="your-client-secret"

# Run it
dotnet run
```

Server runs on `http://localhost:5000` by default.

## Railway Deployment

### 1. Create Railway Project

```bash
# Install Railway CLI if you haven't
npm install -g @railway/cli

# Login and init
railway login
railway init
```

### 2. Set Environment Variables

In Railway dashboard (or CLI), set these:

| Variable | Value | Notes |
|----------|-------|-------|
| `Harvest__ClientId` | `your-client-id` | From Harvest developer settings |
| `Harvest__ClientSecret` | `your-client-secret` | **NEVER commit this** |

Railway auto-injects `PORT` - the Dockerfile handles it.

### 3. Deploy

```bash
railway up
```

Or connect your GitHub repo for auto-deploys.

## iOS App Changes

### Remove from your app:
- `client_secret` (delete it entirely)

### Keep in your app:
- `client_id` (it's public, safe to embed)

### Update OAuth flow:

**Before (insecure):**
```swift
// DON'T DO THIS
let params = [
    "client_id": clientId,
    "client_secret": clientSecret,  // BAD!
    "code": authCode,
    ...
]
POST to https://id.getharvest.com/api/v2/oauth2/token
```

**After (secure):**
```swift
// Token exchange
let params = ["code": authCode, "redirect_uri": "knuckletime://callback"]
POST to https://your-app.railway.app/auth/token

// Token refresh  
let params = ["refresh_token": storedRefreshToken]
POST to https://your-app.railway.app/auth/refresh
```

## API Reference

### POST /auth/token

Exchange authorization code for tokens.

**Request:**
```json
{
  "code": "abc123",
  "redirectUri": "knuckletime://callback"
}
```

**Response:**
```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "expiresIn": 64800,
  "tokenType": "Bearer"
}
```

### POST /auth/refresh

Refresh an expired access token.

**Request:**
```json
{
  "refreshToken": "xyz789"
}
```

**Response:**
```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "expiresIn": 64800,
  "tokenType": "Bearer"
}
```

### Error Responses

| Status | Meaning |
|--------|---------|
| 400 | Missing required field |
| 401 | Invalid/expired refresh token (user must re-auth) |
| 429 | Rate limited (30 req/min per IP) |
| 500 | Server error |

## Security Notes

- **Rate limiting**: 30 requests/minute per IP (plenty for normal use, blocks abuse)
- **No token storage**: This proxy is stateless - tokens pass through, never stored
- **HTTPS**: Railway provides this automatically
- **Secrets**: Only exist in Railway env vars, never in code or config files
