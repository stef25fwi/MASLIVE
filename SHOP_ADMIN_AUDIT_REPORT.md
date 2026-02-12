# SHOP ADMIN – Audit automatique

- Date: 2026-02-11 23:11:42Z
- Repo: /workspaces/MASLIVE

## 1) Arborescence utile (lib/ + functions/ si présent)

total 2364
drwxrwxrwx+  12 vscode root   20480 Feb 11 23:11 .
drwxr-xrwx+   5 vscode root    4096 Feb  8 14:48 ..
-rw-rw-rw-    1 vscode vscode  6114 Feb 10 02:08 00_README_FIRST.md
-rw-rw-rw-    1 vscode vscode   825 Feb 10 02:08 activate_shop_v21.sh
-rw-rw-rw-    1 vscode vscode    86 Feb 10 02:07 add_product.dart
-rw-rw-rw-    1 vscode vscode  6954 Feb 10 02:08 ADMIN_DASHBOARD_STRUCTURE.md
-rw-rw-rw-    1 vscode vscode  3853 Feb 10 02:08 ADMIN_NAVIGATION_VERIFIED.md
-rw-rw-rw-    1 vscode vscode  6525 Feb 10 02:07 ADMIN_POPUP_MODIFICATIONS.md
-rw-rw-rw-    1 vscode vscode 14674 Feb 10 02:07 AMELIORATIONS_ARTICLES_10_10.md
drwxrwxrwx+  18 vscode vscode  4096 Feb 11 11:35 app
-rw-rw-rw-    1 vscode vscode 24777 Feb 10 02:08 ARCHITECTURE_VISUAL.md
-rw-rw-rw-    1 vscode vscode  9618 Feb 10 02:07 AUDIT_ARTICLES_PHOTO_UPLOAD.md
-rw-rw-rw-    1 vscode vscode  9751 Feb 10 02:08 AUDIT_FINAL_ARTICLES_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  4207 Feb 11 18:03 AUDIT_SHOP.md
-rw-rw-rw-    1 vscode vscode 14642 Feb 10 02:07 AUDIT_STORAGE_ARTICLES.md
-rw-rw-rw-    1 vscode vscode 13154 Feb 10 02:08 AUDIT_UPLOAD_ARTICLES_COMPLETE.md
-rw-rw-rw-    1 vscode vscode  6997 Feb 11 18:16 AUDIT_UX_BOUTIQUE.md
-rw-rw-rw-    1 vscode vscode  1305 Feb 10 02:08 BUILD_AND_DEPLOY_HOSTING.md
-rw-rw-rw-    1 vscode vscode   510 Feb 10 02:08 build_and_deploy_hosting.sh
-rw-rw-rw-    1 vscode vscode   255 Feb 10 02:08 build_deploy_now.sh
-rw-rw-rw-    1 vscode vscode   587 Feb 10 02:08 check_analyzer.sh
-rw-rw-rw-    1 vscode vscode  1177 Feb 10 02:08 check_errors.sh
-rw-rw-rw-    1 vscode vscode  7010 Feb 10 02:08 CIRCUIT_WIZARD_PRO_GUIDE.dart
-rwxrwxrwx    1 vscode vscode   771 Feb 10 02:08 clean_and_run_web.sh
-rw-rw-rw-    1 vscode vscode  1053 Feb 10 02:08 clean_build_deploy.sh
-rw-rw-rw-    1 vscode vscode   722 Feb 10 02:08 CLEANUP_COMPLETE.md
-rw-rw-rw-    1 vscode vscode  1937 Feb 10 02:08 cleanup_git_history.sh
-rw-rw-rw-    1 vscode vscode  2066 Feb 10 02:08 cleanup_test_products.js
-rw-rw-rw-    1 vscode vscode 10299 Feb 10 02:08 COMMERCE_TEST_GUIDE.md
-rw-rw-rw-    1 vscode vscode 11098 Feb 10 02:08 COMMERCE_V2_IMPROVEMENTS.md
-rw-rw-rw-    1 vscode vscode  1924 Feb 10 02:08 commit_and_push_now.sh
-rwxrwxrwx    1 vscode vscode  4197 Feb 11 22:35 commit_push_build_deploy.sh
-rw-rw-rw-    1 vscode vscode   883 Feb 10 02:08 commit_quality_fixes.sh
-rw-rw-rw-    1 vscode vscode 12047 Feb 10 02:07 CONFIG_GROUP_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode  4456 Feb 10 02:07 configure_mapbox_now.sh
-rw-rw-rw-    1 vscode vscode  1063 Feb 10 02:08 COPY_PASTE_COMMANDS.md
-rw-rw-rw-    1 vscode vscode  6123 Feb 11 18:26 CORRECTIONS_BOUTIQUE_2026-02-11.md
-rw-rw-rw-    1 vscode vscode 15443 Feb 10 02:07 DASHBOARD_AUDIT_ARTICLES.md
-rw-rw-rw-    1 vscode vscode  8907 Feb 10 02:08 DELIVERABLE_FINAL.md
-rw-rw-rw-    1 vscode vscode 12066 Feb 10 02:08 DELIVERABLE_IMAGE_SYSTEM.md
-rw-rw-rw-    1 vscode vscode 12442 Feb 10 02:08 DELIVERABLE_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode  7606 Feb 10 02:07 DEMARRAGE_RAPIDE_AUDIT.md
-rw-rw-rw-    1 vscode vscode  2787 Feb 10 02:08 DEPLOY_COMMAND.md
-rw-rw-rw-    1 vscode vscode  1697 Feb 10 02:08 DEPLOY_COMMANDS.txt
-rw-rw-rw-    1 vscode vscode  2755 Feb 10 02:08 deploy_complete.sh
-rw-rw-rw-    1 vscode vscode   858 Feb 10 02:07 deploy_firebase.sh
-rw-rw-rw-    1 vscode vscode  1676 Feb 10 02:07 deploy_functions_stripe.sh
-rw-rw-rw-    1 vscode vscode  4129 Feb 10 02:08 deploy_group_tracking.sh
-rwxrwxrwx    1 vscode vscode  1888 Feb 10 02:08 deploy_i18n_now.sh
-rw-rw-rw-    1 vscode vscode  1484 Feb 10 02:08 deploy_i18n.sh
-rw-rw-rw-    1 vscode vscode 11925 Feb 10 02:08 deploy_image_system.sh
-rw-rw-rw-    1 vscode vscode   924 Feb 10 02:08 deploy_main_fast.sh
-rw-rw-rw-    1 vscode vscode  2009 Feb 10 02:08 deploy_main.sh
-rw-rw-rw-    1 vscode vscode  6501 Feb 10 02:08 DEPLOY_MANUAL_STEPS.md
-rwxrwxrwx    1 vscode vscode  5067 Feb 10 02:08 deploy_map_visibility_now.sh
-rw-rw-rw-    1 vscode vscode  8721 Feb 10 02:08 DEPLOYMENT_CHECKLIST_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode  8220 Feb 10 02:08 DEPLOYMENT_CHECKLIST.md
-rw-rw-rw-    1 vscode vscode  5085 Feb 10 02:08 DEPLOYMENT_COMMANDS.md
-rw-rw-rw-    1 vscode vscode  2619 Feb 10 02:08 DEPLOYMENT_COMPLETE.md
-rw-rw-rw-    1 vscode vscode 10441 Feb 10 02:07 DEPLOYMENT_IMAGE_SYSTEM.md
-rw-rw-rw-    1 vscode vscode  5704 Feb 10 02:07 DEPLOYMENT_STATUS_20260124.md
-rw-rw-rw-    1 vscode vscode  1654 Feb 10 02:08 DEPLOY_NOW.md
-rw-rw-rw-    1 vscode vscode  3314 Feb 10 02:08 DEPLOY_NOW.sh
-rw-rw-rw-    1 vscode vscode  3049 Feb 10 02:07 deploy_production.sh
-rw-rw-rw-    1 vscode vscode  5284 Feb 10 02:08 deploy.sh
-rw-rw-rw-    1 vscode vscode  1218 Feb 10 02:08 DEPLOY_SHOP_NOW.md
-rwxrwxrwx    1 vscode vscode  1580 Feb 10 02:08 deploy_shop.sh
-rw-rw-rw-    1 vscode vscode  3850 Feb 10 02:08 deploy_superadmin_articles.sh
drwxrwxrwx+   2 vscode vscode  4096 Feb 10 02:08 .devcontainer
drwxrwxrwx+   2 vscode vscode  4096 Feb 10 02:07 docs
-rw-rw-rw-    1 vscode vscode  8664 Feb 10 02:08 DOCUMENTATION_INDEX.md
-rw-rw-rw-    1 vscode vscode  6507 Feb 10 02:08 DOCUMENTS_CREATED.md
-rw-rw-rw-    1 vscode vscode 17172 Feb 10 02:08 E2E_TESTS_GUIDE.md
-rw-rw-rw-    1 vscode vscode   358 Feb 10 02:08 .env
-rw-rw-rw-    1 vscode vscode   254 Feb 10 02:08 .env.example
-rw-rw-rw-    1 vscode vscode 12145 Feb 10 02:08 EXECUTIVE_SUMMARY_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode  8614 Feb 10 02:08 FEATURE_GROUP_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode 13904 Feb 10 02:07 FILE_MANIFEST_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode  1460 Feb 10 02:08 final_commit.sh
-rw-rw-rw-    1 vscode vscode  4788 Feb 10 02:08 FINAL_DEPLOYMENT_CHECKLIST.md
-rw-rw-rw-    1 vscode vscode  8887 Feb 10 02:08 FINAL_SUMMARY.md
drwxrwxrwx+   2 vscode vscode  4096 Feb 10 02:07 .firebase
-rw-rw-rw-    1 vscode vscode  7043 Feb 10 02:08 firebase_config_report_20260116_180131.txt
-rw-rw-rw-    1 vscode vscode  2060 Feb 10 02:07 firebase.json
-rw-rw-rw-    1 vscode vscode   105 Feb 10 02:08 .firebaserc
-rw-rw-rw-    1 vscode vscode  8614 Feb 10 02:08 FIRESTORE_EXAMPLES.md
-rw-rw-rw-    1 vscode vscode  8616 Feb 10 02:08 firestore.indexes.json
-rw-rw-rw-    1 vscode vscode 26850 Feb 10 02:07 FIRESTORE_MAP_PROJECTS_SCHEMA.md
-rw-rw-rw-    1 vscode vscode 27806 Feb 11 18:13 firestore.rules
-rw-rw-rw-    1 vscode vscode   562 Feb 10 02:08 fix_and_deploy.sh
-rw-rw-rw-    1 vscode vscode  4211 Feb 10 02:08 FIX_GITHUB_PUSH_PROTECTION.md
-rw-rw-rw-    1 vscode vscode  1973 Feb 10 02:08 fix_imports.sh
-rw-rw-rw-    1 vscode vscode   852 Feb 10 02:07 fix_push_and_deploy.sh
-rw-rw-rw-    1 vscode vscode   222 Feb 10 02:07 flutter_clean_get.sh
-rw-rw-rw-    1 vscode vscode  2415 Feb 10 02:08 flutter_doctor.txt
-rw-rw-rw-    1 vscode vscode   826 Feb 10 02:07 force_push_now.sh
-rw-rw-rw-    1 vscode vscode  1699 Feb 10 02:07 FORCE_PUSH_SOLUTION.md
drwxrwxrwx+   5 vscode vscode  4096 Feb 10 02:08 functions
drwxrwxrwx+   8 vscode root    4096 Feb 11 22:54 .git
-rw-rw-rw-    1 vscode vscode  2263 Feb 10 02:08 git_commit_push_build_deploy.sh
-rw-rw-rw-    1 vscode vscode   454 Feb 10 02:08 git_commit_quality.sh
-rw-rw-rw-    1 vscode vscode   293 Feb 10 02:08 .gitcommit.tmp
drwxrwxrwx+   3 vscode vscode  4096 Jan 30 05:14 .github
-rw-rw-rw-    1 vscode vscode  3057 Feb 10 02:08 .gitignore
-rw-rw-rw-    1 vscode vscode  1372 Feb 10 02:08 git_push_main.sh
-rw-rw-rw-    1 vscode vscode  4806 Feb 10 02:08 GO_FOR_DEPLOYMENT.md
-rw-rw-rw-    1 vscode vscode 10741 Feb 10 02:08 GPS_AVERAGE_LOGIC_VERIFICATION.md
-rw-rw-rw-    1 vscode vscode  4161 Feb 10 02:08 GPS_AVERAGE_SUMMARY.md
-rw-rw-rw-    1 vscode vscode 11293 Feb 10 02:07 GROUP_TRACKING_DELIVERABLE.md
-rw-rw-rw-    1 vscode vscode  6278 Feb 10 02:07 GROUP_TRACKING_DEPLOYMENT.md
-rw-rw-rw-    1 vscode vscode  3292 Feb 10 02:08 GROUP_TRACKING_README.md
-rw-rw-rw-    1 vscode vscode  5622 Feb 10 02:08 GROUP_TRACKING_STATUS.md
-rw-rw-rw-    1 vscode vscode 11961 Feb 10 02:07 GROUP_TRACKING_SYSTEM_GUIDE.md
-rw-rw-rw-    1 vscode vscode 13083 Feb 10 02:08 GROUP_TRACKING_TODO.md
-rw-rw-rw-    1 vscode vscode 14545 Feb 10 02:07 GROUP_TRACKING_VERIFICATION.md
-rw-rw-rw-    1 vscode vscode  7502 Feb 10 02:08 GUIDES_INDEX.md
-rw-rw-rw-    1 vscode vscode  3960 Feb 10 02:07 HOMEPAGE_CONFIG_COMMIT_0b19da0.md
-rw-rw-rw-    1 vscode vscode  6546 Feb 10 02:08 I18N_IMPLEMENTATION.md
-rw-rw-rw-    1 vscode vscode  6411 Feb 10 02:08 I18N_READY.md
-rw-rw-rw-    1 vscode vscode 12289 Feb 10 02:08 IMAGE_MANAGEMENT_SYSTEM.md
-rw-rw-rw-    1 vscode vscode 10425 Feb 10 02:08 IMAGE_SYSTEM_INDEX.md
-rw-rw-rw-    1 vscode vscode 14141 Feb 10 02:08 IMAGE_SYSTEM_README.md
-rw-rw-rw-    1 vscode vscode 11770 Feb 10 02:08 IMPLEMENTATION_5_AMELIORATIONS.md
-rw-r--r--    1 vscode vscode 68405 Feb 10 02:10 -iname *i18n*.json -o -iname locales*.json
-rw-rw-rw-    1 vscode vscode  9931 Feb 10 02:08 INDEX_AUDIT_ARTICLES.md
-rw-rw-rw-    1 vscode vscode 13772 Feb 10 02:08 INDEX_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode  3334 Feb 10 02:08 init_articles.js
-rw-rw-rw-    1 vscode vscode  2221 Feb 10 02:07 inspect_shop_products.js
-rw-rw-rw-    1 vscode vscode  2619 Feb 10 02:08 INTEGRATION_EXAMPLES.dart
-rw-rw-rw-    1 vscode vscode 12391 Feb 10 02:08 JOURNAL_MAP_VISIBILITY_IMPLEMENTATION.md
-rw-rw-rw-    1 vscode vscode  1066 Feb 10 02:08 LICENSE
-rw-rw-rw-    1 vscode vscode 10386 Feb 10 02:07 LIVRABLES_AUDIT_ARTICLES.md
-rw-rw-rw-    1 vscode vscode  4923 Feb 10 02:08 LIVRAISON_MAPBOX.md
-rw-rw-rw-    1 vscode vscode  6438 Feb 10 02:08 MAPBOX_3D_IMPLEMENTATION.md
-rw-rw-rw-    1 vscode vscode 12738 Feb 10 02:07 MAPBOX_AUDIT_AND_FIXES.md
-rw-rw-rw-    1 vscode vscode  6941 Feb 10 02:08 MAPBOX_AUDIT_CHECKLIST.md
-rw-rw-rw-    1 vscode vscode  7139 Feb 10 02:07 MAPBOX_AUDIT_COMPLETE.md
-rw-rw-rw-    1 vscode vscode  4570 Feb 10 02:08 MAPBOX_AUDIT_FINAL_REPORT.md
-rw-rw-rw-    1 vscode vscode  1681 Feb 10 02:08 MAPBOX_AUDIT_FINISHED.md
-rw-rw-rw-    1 vscode vscode  5645 Feb 10 02:08 MAPBOX_BUILD_DEPLOY_GUIDE.md
-rw-rw-rw-    1 vscode vscode  2740 Feb 10 02:08 mapbox_build_deploy.sh
-rw-rw-rw-    1 vscode vscode  3485 Feb 10 02:08 MAPBOX_CIRCUIT_FIX.md
-rw-rw-rw-    1 vscode vscode  6074 Feb 10 02:07 MAPBOX_COMMIT_GUIDE.md
-rw-rw-rw-    1 vscode vscode  5839 Feb 10 02:07 MAPBOX_COMPLETION_REPORT.txt
-rw-rw-rw-    1 vscode vscode  3477 Feb 10 02:08 MAPBOX_CONFIG_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  5351 Feb 10 02:07 MAPBOX_CONFIGURATION.md
-rw-rw-rw-    1 vscode vscode  3747 Feb 10 02:07 MAPBOX_DART_DEFINE.md
-rw-rw-rw-    1 vscode vscode  8961 Feb 10 02:08 MAPBOX_DELIVERABLES.md
-rw-rw-rw-    1 vscode vscode  2604 Feb 10 02:07 MAPBOX_DELIVERY_COMPLETE.txt
-rw-rw-rw-    1 vscode vscode  9459 Feb 10 02:08 MAPBOX_DEMO_USAGE.md
-rw-rw-rw-    1 vscode vscode  3914 Feb 10 02:08 MAPBOX_DEPLOYMENT_GUIDE.md
-rw-rw-rw-    1 vscode vscode  7323 Feb 10 02:08 MAPBOX_DOCS_INDEX.md
-rw-rw-rw-    1 vscode vscode  8869 Feb 10 02:08 MAPBOX_FILES_CREATED.md
-rw-rw-rw-    1 vscode vscode  7620 Feb 10 02:08 MAPBOX_FILES_MODIFIED_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  3408 Feb 10 02:08 MAPBOX_FINAL.md
-rw-rw-rw-    1 vscode vscode  9895 Feb 10 02:08 MAPBOX_FINAL_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  4464 Feb 10 02:08 MAPBOX_FIXES_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  3590 Feb 10 02:08 MAPBOX_FLUTTERMAP_AUDIT_20260131.md
-rw-rw-rw-    1 vscode vscode 14500 Feb 10 02:08 MAPBOX_IMPLEMENTATION_COMPLETE.md
-rw-rw-rw-    1 vscode vscode  7313 Feb 10 02:07 MAPBOX_INDEX.md
-rw-rw-rw-    1 vscode vscode  3023 Feb 10 02:08 MAPBOX_INTEGRATION_STATUS.md
-rw-rw-rw-    1 vscode vscode  7540 Feb 10 02:08 MAPBOX_MISSION_COMPLETE.md
-rw-rw-rw-    1 vscode vscode  3328 Feb 10 02:08 MAPBOX_QUICK_START.md
-rw-rw-rw-    1 vscode vscode  3201 Feb 10 02:08 MAPBOX_QUICK_START.txt
-rw-rw-rw-    1 vscode vscode  7344 Feb 10 02:07 MAPBOX_READY_FOR_MERGE.md
-rw-rw-rw-    1 vscode vscode  3316 Feb 10 02:08 MAPBOX_SETUP_QUICK.md
-rw-rw-rw-    1 vscode vscode  4191 Feb 10 02:08 MAPBOX_START_HERE.md
-rw-rw-rw-    1 vscode vscode  3337 Feb 10 02:07 mapbox-start.sh
-rw-rw-rw-    1 vscode vscode  7597 Feb 10 02:08 MAPBOX_STATUS_COMPLETE.md
-rw-rw-rw-    1 vscode vscode  7577 Feb 10 02:08 MAPBOX_TECHNICAL_SUMMARY.md
-rw-rw-rw-    1 vscode vscode 10955 Feb 10 02:08 MAPBOX_TOKEN_SETUP.md
-rw-rw-rw-    1 vscode vscode  8612 Feb 10 02:08 MAPBOX_VALIDATION.md
-rw-rw-rw-    1 vscode vscode 10053 Feb 10 02:07 MAPBOX_VALIDATION_REPORT.md
-rw-rw-rw-    1 vscode vscode 20323 Feb 10 02:08 MAPBOX_VISUAL_OVERVIEW.md
-rw-rw-rw-    1 vscode vscode 11040 Feb 10 02:08 MAPBOX_WEB_GL_IMPLEMENTATION.md
-rw-rw-rw-    1 vscode vscode  6280 Feb 10 02:08 MAPBOX_WHAT_WAS_DONE.md
-rw-rw-rw-    1 vscode vscode  4217 Feb 10 02:07 MAPBOX_WIZARD_UPDATE.md
-rw-rw-rw-    1 vscode vscode  6508 Feb 10 02:08 MAP_DISPLAY_CONFIG.md
-rw-rw-rw-    1 vscode vscode  4985 Feb 10 02:07 MAPMARKET_HOME_INTEGRATION.md
-rw-rw-rw-    1 vscode vscode  9246 Feb 10 02:08 MAPMARKET_WIZARD_COMPLETE.md
-rw-rw-rw-    1 vscode vscode  5935 Feb 10 02:07 MAP_PERMISSIONS_IMPLEMENTATION.md
-rw-rw-rw-    1 vscode vscode  4660 Feb 10 02:08 MAP_PRESETS_IMPLEMENTATION_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  6533 Feb 10 02:07 MAP_PRESETS_SYSTEM.md
-rw-rw-rw-    1 vscode vscode  2361 Feb 10 02:08 maslive-firebase-adminsdk-fbsvc-c6d30fab6a.json
-rw-rw-rw-    1 vscode vscode  5585 Feb 10 02:08 MASLIVE_MAP_SYSTEM.md
-rw-rw-rw-    1 vscode vscode 10777 Feb 10 02:07 MASLIVE_MAP_USAGE.md
-rw-rw-rw-    1 vscode vscode  7547 Feb 10 02:08 MEDIA_COMPARISON.md
-rw-rw-rw-    1 vscode vscode  5962 Feb 10 02:07 MEDIA_SHOP_README.md
-rw-rw-rw-    1 vscode vscode  4934 Feb 10 02:08 MEDIA_SHOP_STRUCTURE.md
-rw-rw-rw-    1 vscode vscode  5072 Feb 10 02:08 migrate_shop_products.js
drwxrwxrwx+ 130 vscode vscode  4096 Feb 10 02:07 node_modules
-rw-rw-rw-    1 vscode vscode    60 Feb 10 02:08 package.json
-rw-rw-rw-    1 vscode vscode 69710 Feb 10 02:08 package-lock.json
-rw-rw-rw-    1 vscode vscode  6907 Feb 10 02:08 PERMISSIONS_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  6796 Feb 10 02:07 POI_ASSISTANT_DELIVERY.md
-rw-rw-rw-    1 vscode vscode  5667 Feb 10 02:08 POI_ASSISTANT_OVERVIEW.md
-rw-rw-rw-    1 vscode vscode 16350 Feb 10 02:08 POI_ASSISTANT_VISUAL_FLOW.md
-rw-rw-rw-    1 vscode vscode  5746 Feb 10 02:08 PRE_PRODUCTION_CHECKLIST.md
-rw-rw-rw-    1 vscode vscode    96 Feb 10 02:08 push_now.sh
-rw-rw-rw-    1 vscode vscode   835 Feb 10 02:08 quick_deploy.sh
-rw-rw-rw-    1 vscode vscode  8621 Feb 10 02:07 QUICK_REFERENCE_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode  8152 Feb 10 02:08 QUICK_START_I18N.md
-rw-rw-rw-    1 vscode vscode  1332 Feb 10 02:07 QUICK_STRIPE_DEPLOY.md
-rw-rw-rw-    1 vscode vscode 15750 Feb 10 02:07 RAPPORT_COMPLET_STRENGTHS_WEAKNESSES.md
-rw-rw-rw-    1 vscode vscode  4962 Feb 10 02:08 README_MAPBOX_AUDIT.md
-rw-rw-rw-    1 vscode vscode  5174 Feb 10 02:08 README_MAPBOX.md
-rw-rw-rw-    1 vscode vscode 14770 Feb 10 02:08 README_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode   598 Feb 10 02:08 README.md
-rw-rw-rw-    1 vscode vscode  9956 Feb 10 02:07 README_SUPERADMIN_ARTICLES.md
-rw-rw-rw-    1 vscode vscode  4772 Feb 10 02:08 README_V21_STRIPE_READY.md
-rw-rw-rw-    1 vscode vscode  3437 Feb 10 02:08 REGENERATE_CREDENTIALS_GUIDE.md
-rw-rw-rw-    1 vscode vscode   430 Feb 10 02:08 remove_assistant_file.sh
-rw-rw-rw-    1 vscode vscode  7511 Feb 10 02:08 RESOLUTION_COMPLETE_5_AMELIORATIONS.md
-rw-rw-rw-    1 vscode vscode  8623 Feb 10 02:07 RESUME_FINAL_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode 11152 Feb 10 02:08 ROLES_AND_PERMISSIONS.md
-rw-rw-rw-    1 vscode vscode   659 Feb 10 02:07 run_flutter_web_clean.sh
-rw-rw-rw-    1 vscode vscode 23084 Feb 10 02:07 run_verbose.txt
drwxrwxrwx+   3 vscode vscode  4096 Feb 10 02:08 scripts
-rw-rw-rw-    1 vscode vscode  4759 Feb 11 22:34 SECURITY_FIX_STRIPE.md
-rw-rw-rw-    1 vscode vscode  2288 Feb 10 02:08 SECURITY_FIX_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  4161 Feb 10 02:08 seed_demo_products.js
-rw-rw-rw-    1 vscode vscode  2360 Feb 10 02:07 serviceAccountKey.json
-rw-rw-rw-    1 vscode vscode   751 Feb 10 02:08 setup_and_test_improvements.sh
-rw-rw-rw-    1 vscode vscode  1666 Feb 10 02:08 setup_i18n.sh
-rw-rw-rw-    1 vscode vscode   152 Feb 11 23:11 SHOP_ADMIN_AUDIT_REPORT.md
-rw-rw-rw-    1 vscode vscode  9028 Feb 10 02:08 START_HERE_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode  4991 Feb 10 02:08 START_HERE.md
-rw-rw-rw-    1 vscode vscode  3816 Feb 10 02:07 START_HERE_V21_STRIPE.md
-rw-rw-rw-    1 vscode vscode 14027 Feb 10 02:08 STATUS_MAP_VISIBILITY_DEPLOYMENT.md
-rw-rw-rw-    1 vscode vscode  3601 Feb 10 02:07 storage.rules
-rw-rw-rw-    1 vscode vscode  8215 Feb 10 02:07 STORAGE_STRUCTURE.md
-rw-rw-rw-    1 vscode vscode 13535 Feb 10 02:08 STORAGE_UPLOAD_VERIFICATION.md
-rw-rw-rw-    1 vscode vscode  1062 Feb 10 02:07 STRIPE_CONFIG_QUICK.md
-rw-rw-rw-    1 vscode vscode   587 Feb 10 02:07 STRIPE_CONFIGURED.md
-rw-rw-rw-    1 vscode vscode  2633 Feb 10 02:07 STRIPE_CORRECTION_LOG.md
-rw-rw-rw-    1 vscode vscode  3357 Feb 10 02:08 STRIPE_SETUP.md
-rw-rw-rw-    1 vscode vscode  2970 Feb 10 02:07 STRIPE_STATUS_OK.md
-rw-rw-rw-    1 vscode vscode  4453 Feb 10 02:07 STRIPE_VERIFICATION_REPORT.md
-rw-rw-rw-    1 vscode vscode   984 Feb 10 02:08 STRIPE_VERIFIED.md
-rw-rw-rw-    1 vscode vscode  5258 Feb 10 02:08 STRIPE_WEBHOOK_SETUP.md
-rw-rw-rw-    1 vscode vscode  1810 Feb 10 02:07 SUMMARY_READY_TO_DEPLOY.md
-rw-rw-rw-    1 vscode vscode 12291 Feb 10 02:07 SUPERADMIN_ARTICLES_ARCHITECTURE.md
-rw-rw-rw-    1 vscode vscode  9218 Feb 10 02:07 SUPERADMIN_ARTICLES_DEPLOYMENT_CHECKLIST.md
-rw-rw-rw-    1 vscode vscode  9516 Feb 10 02:08 SUPERADMIN_ARTICLES_GUIDE.md
-rw-rw-rw-    1 vscode vscode 10072 Feb 10 02:08 SUPERADMIN_ARTICLES_INVENTORY.md
-rw-rw-rw-    1 vscode vscode  5013 Feb 10 02:08 SUPERADMIN_ARTICLES_QUICKSTART.md
-rw-rw-rw-    1 vscode vscode  6892 Feb 10 02:08 SUPERADMIN_ARTICLES_SUMMARY.md
-rw-rw-rw-    1 vscode vscode 10732 Feb 10 02:08 SUPERADMIN_ARTICLES_TESTS.md
-rw-rw-rw-    1 vscode vscode 16079 Feb 10 02:08 SUPERADMIN_ARTICLES_UI.md
-rw-rw-rw-    1 vscode vscode 18298 Feb 10 02:08 SYSTEM_ARCHITECTURE_VISUAL.md
-rw-rw-rw-    1 vscode vscode 11111 Feb 10 02:08 SYSTEM_READY_TO_DEPLOY.md
-rw-rw-rw-    1 vscode vscode  5974 Feb 10 02:08 TASK_SUMMARY.md
-rw-r--r--    1 vscode vscode  3073 Feb 10 02:08 tates"
-rw-r--r--    1 vscode vscode  8192 Feb 10 02:08 tatus
-rw-r--r--    1 vscode vscode 18923 Feb 10 02:08 te du diff
-rw-rw-rw-    1 vscode vscode  8503 Feb 10 02:07 TEST_AJOUT_ARTICLE_COMPLET.md
-rw-rw-rw-    1 vscode vscode 10926 Feb 10 02:08 TESTING_GROUP_MAP_VISIBILITY.md
-rw-rw-rw-    1 vscode vscode 11703 Feb 10 02:08 TESTS_ARTICLES_PHOTO_GUIDE.md
-rw-rw-rw-    1 vscode vscode  3492 Feb 10 02:08 TROUBLESHOOTING_IMPORTS.md
-rw-rw-rw-    1 vscode vscode  3667 Feb 10 02:07 UNLOCK_GITHUB_PUSH.md
-rw-rw-rw-    1 vscode vscode  1602 Feb 10 02:08 UNLOCK_NOW.txt
-rw-rw-rw-    1 vscode vscode  1298 Feb 10 02:08 update_v3_branch.sh
-rw-rw-rw-    1 vscode vscode  4572 Feb 10 02:08 V21_DEPLOYMENT.md
-rw-rw-rw-    1 vscode vscode  1736 Feb 10 02:08 validate_and_commit.sh
-rw-rw-rw-    1 vscode vscode  5635 Feb 10 02:08 VALIDATION_AND_DEPLOYMENT.md
-rw-rw-rw-    1 vscode vscode   850 Feb 10 02:08 verify_files.sh
-rw-rw-rw-    1 vscode vscode  2973 Feb 10 02:07 verify_mapbox_fixes.sh
-rw-rw-rw-    1 vscode vscode 10408 Feb 10 02:08 VISUAL_SUMMARY.md
drwxrwxrwx+   2 vscode vscode  4096 Feb 11 13:47 .vscode
-rw-rw-rw-    1 vscode vscode 18562 Feb 10 02:08 WIZARD_CIRCUIT_RAPPORT.md
-rw-rw-rw-    1 vscode vscode  2310 Feb 10 02:07 WIZARD_IMPROVEMENTS_SUMMARY.md
-rw-rw-rw-    1 vscode vscode  5654 Feb 10 02:07 WIZARD_UX_IMPROVEMENTS.md

### functions/ (top-level)
total 256
drwxrwxrwx+   5 vscode vscode   4096 Feb 10 02:08 .
drwxrwxrwx+  12 vscode root    20480 Feb 11 23:11 ..
-rw-rw-rw-    1 vscode vscode    252 Feb 10 02:08 .env.example
-rw-rw-rw-    1 vscode vscode   7570 Feb 10 02:07 group_tracking_improved.js
-rw-rw-rw-    1 vscode vscode   7697 Feb 11 22:13 group_tracking.js
-rw-rw-rw-    1 vscode vscode  89782 Feb 11 22:34 index.js
-rw-rw-rw-    1 vscode vscode   7055 Feb 10 02:08 index.js.bak.20260117152201
drwxrwxrwx+ 183 vscode vscode   4096 Feb 11 22:55 node_modules
-rw-rw-rw-    1 vscode vscode    404 Feb 10 02:08 package.json
-rw-rw-rw-    1 vscode vscode 101316 Feb 10 02:08 package-lock.json
drwxrwxrwx+   2 vscode vscode   4096 Feb 10 02:08 scripts
drwxrwxrwx+   2 vscode vscode   4096 Feb 10 02:08 src

## 2) Fichiers candidats: ProductService / StorageService / AddProductPage / Shop Drawer / Routes

### 2.1 Recherche ProductService / StorageService


### 2.2 Recherche AddProductPage / pages d’admin / profile admin


### 2.3 Recherche Drawer / Menu burger boutique


### 2.4 Recherche Routing (GoRouter/AutoRoute/Navigator/routes)


## 3) Rôle & permissions: groupAdmin / claims / guard


## 4) Firestore: chemins de collections utilisés (products/orders/stock…)


## 5) Extraits des fichiers clés (si trouvés)

### ProductService — introuvable automatiquement (à localiser manuellement)

### StorageService — introuvable automatiquement (à localiser manuellement)

### AddProductPage (ou équivalent) — introuvable automatiquement (à localiser manuellement)

### Drawer / Menu burger — introuvable automatiquement (à localiser manuellement)

### Router / Routes — introuvable automatiquement (à localiser manuellement)

## 6) Résumé chemins détectés

- ProductService: NON TROUVÉ
- StorageService: NON TROUVÉ
- AddProductPage: NON TROUVÉ
- Drawer: NON TROUVÉ
- Router/Routes: NON TROUVÉ

