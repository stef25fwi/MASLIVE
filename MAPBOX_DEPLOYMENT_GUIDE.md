# 🚀 Mapbox Wizard - Deployment Guide

## Quick Start

### 1. **Locally (Development)**
```bash
cd /workspaces/MASLIVE/app

# Without Mapbox (preview mode):
flutter build web --release

# With Mapbox:
export MAPBOX_TOKEN="pk_YOUR_PUBLIC_TOKEN_HERE"
flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"

# Then deploy:
cd ..
firebase deploy --only hosting
```

### 2. **CI/CD (GitHub Actions)**
Add to your workflow:
```yaml
- name: Build Flutter Web with Mapbox
  run: |
    cd app
    flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN=${{ secrets.MAPBOX_PUBLIC_TOKEN }}
    cd ..
    
- name: Deploy to Firebase Hosting
  run: firebase deploy --only hosting
```

## Environment Variables

### ✅ Mapbox Public Token
- **Type**: Public (safe to embed)
- **Prefix**: `pk_`
- **Where to get**: mapbox.com/account/tokens
- **Restrictions**: 
  - Set appropriate domains/IPs
  - Limit scopes to `maps:read`

### ⚠️ Mapbox Secret Token
- **Type**: Secret (never embed!)
- **Prefix**: `sk_`
- **Use case**: Backend services only

## Configuration

### VSCode Tasks (tasks.json)
```json
{
  "label": "MASLIVE: Build Web with Mapbox",
  "type": "shell",
  "command": "cd /workspaces/MASLIVE/app && flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN=\"pk_YOUR_TOKEN\"",
  "group": { "kind": "build", "isDefault": false }
},
{
  "label": "MASLIVE: Deploy Web (Mapbox Ready)",
  "type": "shell",
  "command": "cd /workspaces/MASLIVE/app && flutter pub get && flutter build web --release --dart-define=MAPBOX_ACCESS_TOKEN=\"pk_YOUR_TOKEN\" && cd .. && firebase deploy --only hosting",
  "group": { "kind": "build" }
}
```

## Features Deployed

### ✅ Display
- [x] Mapbox GL JS renders in wizard preview
- [x] Streets style by default
- [x] Navigation controls (zoom, compass)
- [x] 3D buildings layer
- [x] Responsive on desktop/tablet

### ✅ Interactions
- [x] Point placement via overlay taps
- [x] Undo/Clear buttons
- [x] Real-time point counter
- [x] Validation feedback
- [x] Status badge (Mapbox/Aperçu)

### ⏳ TODO (Future Phases)
- [ ] Native Mapbox click detection
- [ ] Live polygon drawing
- [ ] Distance calculations
- [ ] Custom layers (routes, POIs)
- [ ] Satellite + terrain views

## Troubleshooting

### Map displays blank
```
❌ MAPBOX_ACCESS_TOKEN not passed at build time
✅ Solution: flutter build web --dart-define=MAPBOX_ACCESS_TOKEN="pk_..."
```

### Fallback to grid showing
```
❌ Token is empty or invalid
✅ Solution: Check token prefix (pk_) and validity in Mapbox dashboard
```

### Navigation controls missing
```
❌ Mapbox JS initialization delayed
✅ Solution: Already handled with 100ms delay, try hard refresh browser
```

### SSL Certificate errors
```
❌ Mapbox domain not allowed on your origin
✅ Solution: Add domain to token restrictions in Mapbox account
```

## Before Deploy Checklist

```
[ ] Mapbox token generated (pk_...)
[ ] Domain added to token restrictions
[ ] Mapbox scopes: maps:read (minimum)
[ ] Build tested locally with token
[ ] Grid fallback tested (without token)
[ ] Flutter analyze passes
[ ] No console errors in browser DevTools
[ ] Points can be placed on map
[ ] Undo/Clear buttons work
[ ] Validation flow works
```

## Rollback Plan

If issues occur:
```bash
# Revert to previous build (no Mapbox):
cd /workspaces/MASLIVE
git revert HEAD~1  # If needed
firebase deploy --only hosting

# Or deploy from previous tag:
git checkout v1.0
flutter build web --release
firebase deploy --only hosting
```

## Support

### Mapbox Issues
- Dashboard: https://app.mapbox.com
- Docs: https://docs.mapbox.com/web/maps/
- Status: https://status.mapbox.com

### Flutter Issues
- Docs: https://flutter.dev/web
- Issues: https://github.com/flutter/flutter/issues

---

**Status**: 🟢 Ready for Production  
**Last Updated**: 2025-01-24  
**Token Requirement**: Public `pk_` token from Mapbox account
