#!/bin/bash

# Script pour supprimer le fichier create_circuit_assistant_page.dart

cd /workspaces/MASLIVE

# Supprimer le fichier du dépôt Git
git rm app/lib/admin/create_circuit_assistant_page.dart

# Afficher le statut
echo "Fichier supprimé. Statut Git:"
git status

echo ""
echo "Pour commiter cette suppression, exécutez:"
echo "git commit -m \"fix: suppression du fichier create_circuit_assistant_page.dart corrompu\""
