#!/bin/bash
# Setup Claude Code authentication in devcontainer

set -e

CLAUDE_DIR="${HOME}/.claude"
CLAUDE_JSON="${HOME}/.claude.json"
CREDENTIALS_FILE="${CLAUDE_DIR}/.credentials.json"

echo "🔍 Checking Claude Code configuration..."

# Check if .claude directory exists
if [ ! -d "${CLAUDE_DIR}" ]; then
  echo "❌ Claude directory not found"
  echo "   Please ensure the devcontainer mounts are configured correctly"
  exit 1
fi

echo "✅ Claude directory found"

# Prefer modern auth/config file and keep legacy support.
if [ -f "${CLAUDE_JSON}" ]; then
  echo "✅ Claude JSON config found"
elif [ -f "${CREDENTIALS_FILE}" ]; then
  echo "✅ Legacy credentials file found"
else
  echo "⚠️  No Claude auth/config file found"
  echo "   You may need to login to Claude Code manually"
  exit 0
fi

# Check file permissions (omit path to avoid leaking layout in recordings)
if [ -f "${CLAUDE_JSON}" ]; then
  PERMS=$(stat -c "%a" "${CLAUDE_JSON}" 2>/dev/null || stat -f "%Lp" "${CLAUDE_JSON}" 2>/dev/null || echo "unknown")
  echo "📋 Claude JSON file permissions: ${PERMS}"
else
  PERMS=$(stat -c "%a" "${CREDENTIALS_FILE}" 2>/dev/null || stat -f "%Lp" "${CREDENTIALS_FILE}" 2>/dev/null || echo "unknown")
  echo "📋 Legacy credentials file permissions: ${PERMS}"
fi

# Ensure proper ownership (in case UID mapping is different)
TARGET_FILE="${CLAUDE_JSON}"
if [ ! -f "${TARGET_FILE}" ]; then
  TARGET_FILE="${CREDENTIALS_FILE}"
fi
if [ "$(stat -c "%U" "${TARGET_FILE}" 2>/dev/null)" != "$(whoami)" ]; then
  echo "⚠️  Config file owner mismatch, but this is expected with bind mounts"
fi

# Verify config file is valid JSON
if ! jq empty "${TARGET_FILE}" 2>/dev/null; then
  echo "⚠️  Config file is not valid JSON"
  exit 0
fi

echo "✅ Claude config is valid JSON"

# Check if Claude Code is installed
if ! command -v claude &> /dev/null; then
  echo "⚠️  Claude Code CLI not found in PATH"
  echo "   This is OK if you're using the VS Code extension"
  exit 0
fi

echo "✅ Claude Code CLI found"

# Test authentication (non-blocking)
if claude auth status &> /dev/null; then
  echo "✅ Claude Code is authenticated!"
else
  echo "⚠️  Claude Code authentication check failed"
  echo "   Please run 'claude auth login' if needed"
fi

echo "✨ Claude Code setup complete"
