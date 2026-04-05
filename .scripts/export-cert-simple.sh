#!/bin/bash
# Simple certificate export for Conveyor CI
# Exports just the certificate (not the private key)

set -e

echo "🔐 Exporting Developer ID Application certificate..."
echo ""

# Find the Developer ID Application certificate
CERT_NAME=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | sed 's/.*"\(.*\)"/\1/')

if [ -z "$CERT_NAME" ]; then
  echo "❌ Error: No Developer ID Application certificate found"
  echo "   Make sure you have a valid Developer ID certificate in your Keychain"
  exit 1
fi

echo "Found certificate: $CERT_NAME"
echo ""

# Export certificate only (no private key needed)
security find-certificate -c "$CERT_NAME" -p > developerID_application.cer

echo "✓ Certificate exported to: developerID_application.cer"
echo ""
echo "📋 Base64 encoded certificate (copy this to GitHub secret APPLE_CERTIFICATE_BASE64):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
base64 < developerID_application.cer
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Done! The base64 output above is in your clipboard (if pbcopy available)"

# Try to copy to clipboard if available
if command -v pbcopy &> /dev/null; then
  base64 < developerID_application.cer | pbcopy
  echo "   (Already copied to clipboard)"
fi

echo ""
echo "⚠️  Keep developerID_application.cer secure - it's already in .gitignore"
