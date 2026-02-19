#!/usr/bin/env bash
#
# REQUIREMENTS:
# 1. Install jq: `sudo apt install jq` (Debian/Ubuntu) or `brew install jq` (Mac)
# 2. Set these environment variables:
#    - DROPBOX_CLIENT_ID: Your Dropbox app's client ID
#    - DROPBOX_CLIENT_SECRET: Your Dropbox app's client secret
#    - DROPBOX_REFRESH_TOKEN: Your long-lived refresh token (from initial auth)
# 3. Do NOT set DROPBOX_API_ACCESS_TOKEN (the script manages it)

URL="https://content.dropboxapi.com/2/files/download_zip"
TRANSLATION_ARGS="Dropbox-API-Arg: {\"path\":\"/A Homeric translation IP/\"}"
TRANSLATION_DESTINATION="translation/ahcip.zip"

# Check for required tools
if ! command -v jq &> /dev/null; then
  echo "Error: 'jq' is required. Install it with 'sudo apt install jq' or 'brew install jq'."
  exit 1
fi

# Function to refresh access token
refresh_token() {
  local response
  response=$(curl -s -X POST "https://api.dropboxapi.com/oauth2/token" \
    -d "grant_type=refresh_token" \
    -d "refresh_token=$DROPBOX_REFRESH_TOKEN" \
    -d "client_id=$DROPBOX_CLIENT_ID" \
    -d "client_secret=$DROPBOX_CLIENT_SECRET")

  if echo "$response" | grep -q "error"; then
    echo "Error refreshing token: $(echo "$response" | jq -r '.error_description')"
    exit 1
  fi
  echo "$response" | jq -r '.access_token'
}

# Initial auth header (will fail if token expired)
AUTH_HEADER="Authorization: Bearer $DROPBOX_API_ACCESS_TOKEN"

# Try download with current token, capture HTTP status
temp_file=$(mktemp)
http_code=$(curl -X POST "$URL" \
  --header "$AUTH_HEADER" \
  --header "$TRANSLATION_ARGS" \
  -o "$temp_file" \
  -w "%{http_code}" -s)

# Handle 401 (Unauthorized) by refreshing token
if [ "$http_code" = "401" ]; then
  echo "Access token expired. Refreshing..."
  NEW_TOKEN=$(refresh_token)
  AUTH_HEADER="Authorization: Bearer $NEW_TOKEN"
  echo "Retrying download with new token..."
  curl -X POST "$URL" --header "$AUTH_HEADER" --header "$TRANSLATION_ARGS" -o "$TRANSLATION_DESTINATION"
else
  # Move successful response to destination
  mv "$temp_file" "$TRANSLATION_DESTINATION"
fi

# Cleanup temporary file (if not used)
rm -f "$temp_file"

unzip "$TRANSLATION_DESTINATION" -d "translation/ahcip"

rm "$TRANSLATION_DESTINATION"