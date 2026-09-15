#!/usr/bin/env bash
#
# Create the Blushy backend as a new Render web service, on any Render account.
#
# Why this exists: `render blueprints` can only *validate* render.yaml -- there
# is no CLI command that applies one -- so a CLI-created service has to restate
# what render.yaml declares. This does that, and pulls the secrets out of
# BLUSHY_MAINAPP/backend/.env at run time so they never have to be typed or
# pasted anywhere.
#
# It deliberately does NOT copy that .env wholesale. That file is a development
# config, and four of its values are wrong or unsafe in production:
#
#   NODE_ENV=development                  -> forced to production
#   CORS_ORIGIN=...,*                     -> app.js THROWS on '*' in production
#   EMAIL_DELIVERY_FALLBACK_ENABLED=true  -> returns signup codes in the API
#                                            response; an account takeover
#   JWT_SECRET=your-secret-...            -> a placeholder, long enough to pass
#                                            validation but not to be trusted
#
# So those are supplied here instead of inherited. Everything else that is a
# real credential (Atlas, Brevo, Google, the AI keys) is carried across as-is.
#
# Usage:
#   ./deploy-render.sh                       # dry run: prints the command, secrets masked
#   ./deploy-render.sh --run                 # actually creates the service
#   CORS_ORIGIN=https://x.vercel.app ./deploy-render.sh --run
#
# Prerequisites:
#   RENDER_API_KEY   an API key for the TARGET account (Account Settings -> API Keys)
#   RENDER_BIN       path to the render binary (default: ./render.exe, then `render`)

set -euo pipefail

# Git Bash rewrites any argument that looks like a Unix path into a Windows one
# before the process sees it, so `--health-check-path /health` reached Render as
# "C:/Program Files/Git/health" and the health check pointed at nothing. It is
# silent: the command succeeds and the service is created with the wrong value.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# There are two env files and they are not copies of each other:
#
#   BLUSHY_MAINAPP/backend/.env   development -- NODE_ENV=development, localhost
#                                 URLs, and mongodb://127.0.0.1
#   BLUSHY_MAINAPP/.env           production  -- NODE_ENV=production, the Atlas
#                                 cluster, blushy.life
#
# 21 keys are identical (every shared credential); 7 differ, and on those the
# production file is the one that is right for a deploy. So both are read, in
# that order, and the second overlays the first.
#
# Which one the server itself picks up locally depends on where you launch it
# from: `dotenv.config()` reads `.env` relative to the working directory, so
# `node src/server.js` from backend/ gets the dev file, while running it from
# BLUSHY_MAINAPP/ gets the production one.
ENV_FILES=(
  "$REPO_ROOT/BLUSHY_MAINAPP/backend/.env"
  "$REPO_ROOT/BLUSHY_MAINAPP/.env"
)

# ---------------------------------------------------------------- settings --
# These mirror render.yaml. Override any of them from the environment.
SERVICE_NAME="${SERVICE_NAME:-blushy-api}"
REPO_URL="${REPO_URL:-https://github.com/devblushy/blushy}"
BRANCH="${BRANCH:-main}"
ROOT_DIR="${ROOT_DIR:-BLUSHY_MAINAPP/backend}"
BUILD_COMMAND="${BUILD_COMMAND:-npm ci --omit=dev}"
START_COMMAND="${START_COMMAND:-node src/server.js}"
HEALTH_CHECK_PATH="${HEALTH_CHECK_PATH:-/health}"
PLAN="${PLAN:-free}"
# render.yaml names no region, so the CLI would default to Oregon. The app runs
# on Asia/Kolkata time, so Singapore is the closer default.
REGION="${REGION:-singapore}"

RUN=0
if [ "${1:-}" = "--run" ]; then RUN=1; fi

# ------------------------------------------------------------------- tools --
if [ -n "${RENDER_BIN:-}" ]; then
  RENDER="$RENDER_BIN"
elif [ -x "$REPO_ROOT/render.exe" ]; then
  RENDER="$REPO_ROOT/render.exe"
elif command -v render >/dev/null 2>&1; then
  RENDER="render"
else
  echo "error: render CLI not found." >&2
  echo "  download: https://github.com/render-oss/cli/releases/latest" >&2
  echo "  or set RENDER_BIN=/path/to/render" >&2
  exit 1
fi

# ------------------------------------------------------------ read the env --
# Parsed, never sourced: sourcing an .env executes whatever is in it.
# Later files overlay earlier ones, so the production file wins where they differ.
declare -A SRC
found_any=0
for env_file in "${ENV_FILES[@]}"; do
  [ -f "$env_file" ] || continue
  found_any=1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    if [ "${line#*=}" = "$line" ]; then continue; fi
    key="${line%%=*}"
    val="${line#*=}"
    key="$(printf '%s' "$key" | tr -d '[:space:]')"
    val="${val%$'\r'}"
    # strip one layer of surrounding quotes, if present
    case "$val" in
      \"*\") val="${val#\"}"; val="${val%\"}" ;;
      \'*\') val="${val#\'}"; val="${val%\'}" ;;
    esac
    # An empty value never overlays a real one from the previous file.
    if [ -n "$val" ] || [ -z "${SRC[$key]:-}" ]; then SRC["$key"]="$val"; fi
  done < "$env_file"
done
[ "$found_any" = "1" ] || { echo "error: none of these env files exist: ${ENV_FILES[*]}" >&2; exit 1; }

# first non-empty of the named keys
pick() {
  local k
  for k in "$@"; do
    if [ -n "${SRC[$k]:-}" ]; then printf '%s' "${SRC[$k]}"; return; fi
  done
}

# ------------------------------------------------- values you must supply --
# CORS_ORIGIN is not optional: with it unset or '*', app.js throws at startup in
# production and the service never comes up.
# Not defaulted from the env file on purpose: a new deployment has a new web
# origin, and silently inheriting the old list would leave the new site blocked.
CORS_ORIGIN="${CORS_ORIGIN:-}"
if [ -z "$CORS_ORIGIN" ]; then
  echo "error: CORS_ORIGIN is required -- the exact origin(s) of your web deploy." >&2
  echo "  example: CORS_ORIGIN=https://blushy-web-upload.vercel.app ./deploy-render.sh" >&2
  existing="$(pick CORS_ORIGIN)"
  if [ -n "$existing" ]; then
    echo >&2
    echo "  the env files currently carry, if you want to extend it:" >&2
    echo "    $existing" >&2
  fi
  exit 1
fi
case "$CORS_ORIGIN" in
  *'*'*) echo "error: CORS_ORIGIN cannot contain '*' -- the backend refuses it in production." >&2; exit 1 ;;
esac

# Used to build the links in verification emails. Prefer whatever the
# production env file names; fall back to the first CORS origin.
APP_PUBLIC_URL="${APP_PUBLIC_URL:-$(pick APP_PUBLIC_URL)}"
case "$APP_PUBLIC_URL" in
  ''|*localhost*|*127.0.0.1*) APP_PUBLIC_URL="${CORS_ORIGIN%%,*}" ;;
esac

# A fresh secret by default. Reusing the dev placeholder would let anyone who
# has seen this repo mint valid tokens; rotating it only signs everyone out.
JWT_SECRET="${JWT_SECRET:-}"
JWT_GENERATED=0
if [ -z "$JWT_SECRET" ]; then
  JWT_SECRET="$(node -e 'process.stdout.write(require("crypto").randomBytes(48).toString("base64url"))')"
  JWT_GENERATED=1
fi
[ "${#JWT_SECRET}" -ge 32 ] || { echo "error: JWT_SECRET must be at least 32 characters." >&2; exit 1; }

# ------------------------------------------------------- assemble env vars --
declare -a ENVV
# `return 0` matters: without it an empty value makes the final `[ -n ... ]`
# fail, the function returns 1, and `set -e` kills the script on the first
# variable that happens to be unset.
add() {
  if [ -n "$2" ]; then ENVV+=("--env-var" "$1=$2"); fi
  return 0
}

# Forced, not inherited.
add NODE_VERSION                    "24"
add NODE_ENV                        "production"
add IP_RATE_LIMIT_MAX               "600"
add EMAIL_DELIVERY_FALLBACK_ENABLED "false"
add EMAIL_FROM_NAME                 "$(pick EMAIL_FROM_NAME)"
add CORS_ORIGIN                     "$CORS_ORIGIN"
add APP_PUBLIC_URL                  "$APP_PUBLIC_URL"
add JWT_SECRET                      "$JWT_SECRET"

# The database is the one value most likely to be wrong here. The dev env file
# points at mongodb://127.0.0.1:27017/blushy, and on Render that is the
# container's own loopback -- the service starts, finds nothing, and exits with
# "Failed to connect to MongoDB after multiple attempts". Refuse it rather than
# deploy something that cannot come up.
MONGODB_URI="${MONGODB_URI:-$(pick MONGODB_URI)}"
case "$MONGODB_URI" in
  *127.0.0.1*|*localhost*)
    echo "error: MONGODB_URI points at localhost -- that is the dev database." >&2
    echo "  Render has no database at its own loopback, so the service would not start." >&2
    echo "  Supply the Atlas connection string:" >&2
    echo "    MONGODB_URI='mongodb+srv://...' CORS_ORIGIN='...' ./deploy-render.sh --run" >&2
    exit 1 ;;
esac

# Carried across from the dev env file.
add MONGODB_URI              "$MONGODB_URI"
add ENCRYPTION_KEY           "$(pick ENCRYPTION_KEY)"
add BREVO_API_KEY            "$(pick BREVO_API_KEY)"
add EMAIL_FROM               "$(pick EMAIL_FROM)"
add GOOGLE_CLIENT_ID_WEB     "$(pick GOOGLE_CLIENT_ID_WEB)"
add GOOGLE_CLIENT_ID_ANDROID "$(pick GOOGLE_CLIENT_ID_ANDROID)"
add GOOGLE_CLIENT_ID_IOS     "$(pick GOOGLE_CLIENT_ID_IOS)"
add MOBILE_APP_DEEP_LINK_BASE "$(pick MOBILE_APP_DEEP_LINK_BASE)"

# The AI provider is read under canonical names in render.yaml but the dev file
# still uses the older GROK_* spellings, so both are accepted here and emitted
# canonically. Chat (OpenRouter, sk-or-) and speech-to-text (Groq, gsk_) are
# different providers -- see the note in utils/env.js.
add AI_CHAT_API_KEY          "$(pick AI_CHAT_API_KEY OPENROUTER_API_KEY GROK_API_KEY)"
add AI_CHAT_MODEL            "$(pick AI_CHAT_MODEL GROK_MODEL)"
add AI_CHAT_API_URL          "$(pick AI_CHAT_API_URL GROK_API_URL)"
add SPEECH_TO_TEXT_API_KEY   "$(pick SPEECH_TO_TEXT_API_KEY GROQ_API_KEY)"
add SPEECH_TO_TEXT_MODEL     "$(pick SPEECH_TO_TEXT_MODEL)"
add SPEECH_TO_TEXT_URL       "$(pick SPEECH_TO_TEXT_URL)"

# Object storage. Absent means uploads land on the instance's own disk, which is
# wiped on every deploy and every sleep-wake.
add S3_BUCKET            "$(pick S3_BUCKET)"
add S3_REGION            "$(pick S3_REGION)"
add S3_ACCESS_KEY_ID     "$(pick S3_ACCESS_KEY_ID)"
add S3_SECRET_ACCESS_KEY "$(pick S3_SECRET_ACCESS_KEY)"
add S3_ENDPOINT          "$(pick S3_ENDPOINT)"
add S3_PUBLIC_BASE_URL   "$(pick S3_PUBLIC_BASE_URL)"

add REDIS_URL "$(pick REDIS_URL)"
add FCM_SERVICE_ACCOUNT_JSON "$(pick FCM_SERVICE_ACCOUNT_JSON)"

# Deliberately NOT carried over:
#   PORT, API_BASE_URL   Render supplies its own
#   DNS_SERVERS          only for networks that refuse SRV lookups; Render is fine
#   HF_TOKEN             used by scripts/, never read by the server
#   SMTP_*               Brevo's HTTP API is tried first and SMTP ports are
#                        commonly blocked on hosted platforms

# ---------------------------------------------------------------- warnings --
warn() { printf '  ! %s\n' "$1"; }
echo
echo "Blushy backend -> Render"
echo "  service   $SERVICE_NAME  ($PLAN, $REGION)"
echo "  repo      $REPO_URL  [$BRANCH]  root=$ROOT_DIR"
echo "  env vars  ${#ENVV[@]} flags ($(( ${#ENVV[@]} / 2 )) variables)"
echo
[ "$JWT_GENERATED" = "1" ] && warn "JWT_SECRET was generated fresh. Save it: existing sessions elsewhere will not validate against it."
[ -z "$(pick S3_BUCKET)" ] && warn "No S3_* configured: uploaded images and voice notes will be lost on every deploy."
[ -z "$(pick MONGODB_URI)" ] && warn "MONGODB_URI is empty -- the service will not start."
[ -z "$(pick BREVO_API_KEY)" ] && warn "No BREVO_API_KEY: signup verification emails will not send."
[ "$PLAN" = "free" ] && warn "Free plan: the instance sleeps when idle and the first request pays a cold start."
warn "Atlas Network Access must allow 0.0.0.0/0 -- a free Render service has no fixed outbound IP."
warn "The Flutter app has the OLD backend URL compiled in. To point it here, rebuild with:"
echo "      flutter build web --release --dart-define=API_BASE_URL=https://<new-service>.onrender.com"
echo

# ------------------------------------------------------------------- go/no --
declare -a ARGS=(
  services create
  --name "$SERVICE_NAME"
  --type web_service
  --runtime node
  --repo "$REPO_URL"
  --branch "$BRANCH"
  --root-directory "$ROOT_DIR"
  --build-command "$BUILD_COMMAND"
  --start-command "$START_COMMAND"
  --health-check-path "$HEALTH_CHECK_PATH"
  --plan "$PLAN"
  --region "$REGION"
  "${ENVV[@]}"
  --output json
  --confirm
)

if [ "$RUN" != "1" ]; then
  # Masked so the command can be read and checked without spilling anything.
  echo "DRY RUN -- re-run with --run to create the service."
  echo
  printf '%s' "$RENDER"
  local_mask=0
  for a in "${ARGS[@]}"; do
    if [ "$local_mask" = "1" ]; then
      key="${a%%=*}"; val="${a#*=}"
      case "$key" in
        *KEY|*SECRET|*URI|*TOKEN|*PASSWORD|*JSON) printf " '%s=%s'" "$key" "<${#val} chars hidden>" ;;
        *) printf " '%s'" "$a" ;;
      esac
      local_mask=0
      continue
    fi
    [ "$a" = "--env-var" ] && local_mask=1
    printf " %s" "$(printf '%q' "$a")"
  done
  echo
  echo
  exit 0
fi

[ -n "${RENDER_API_KEY:-}" ] || echo "note: RENDER_API_KEY is not set; the CLI will use whichever account you are logged into." >&2

echo "Creating the service..."
"$RENDER" "${ARGS[@]}"
