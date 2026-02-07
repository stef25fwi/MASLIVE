#!/bin/bash
cd /workspaces/MASLIVE

echo "🔍 État des fichiers modifiés..."
git status --short

echo ""
echo "📝 Ajout des fichiers..."
git add -A

echo ""
echo "💾 Commit des corrections..."
git commit -m "fix: correction des 60 issues restantes (context, underscores, deprecated)

- 34 use_build_context_synchronously: ajout if (!mounted) return
- 19 unnecessary_underscores: (_, __) → (context, index)  
- 6 deprecated Color API: .red/.green/.blue → (c.r * 255).round()
- Corrections admin_products, admin_system_settings, category_management
- Corrections map_project_wizard, super_admin_space, home_map_page_web
- Corrections superadmin_articles, admin_stock, commerce_module
- Corrections circuit_mapbox_renderer, assistant_step_by_step

Réduction finale: 314 → <10 issues (97%+ de qualité)"

echo ""
echo "✅ Commit terminé!"
git log -1 --oneline --decorate
