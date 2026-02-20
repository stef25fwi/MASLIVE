#!/usr/bin/env bash
set -euo pipefail
OUT="/workspaces/MASLIVE/wizard_circuit_files.zip"
rm -f "$OUT"
cd /workspaces/MASLIVE/app/lib
zip "$OUT" \
  ui/wizard/pro_circuit_wizard_page.dart \
  providers/wizard_circuit_provider.dart \
  services/circuit_repository.dart
echo "✅ ZIP créé : $OUT"
ls -lh "$OUT"
