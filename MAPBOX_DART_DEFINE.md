# Token Mapbox via --dart-define

## Méthode propre : passer le token au build

Au lieu d'écrire ton token Mapbox en dur dans `web/index.html`, tu peux le passer via `--dart-define` :

### Flutter Web (développement)

```bash
cd /workspaces/MASLIVE/app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=MAPBOX_ACCESS_TOKEN=ton_token_ici
```

### Flutter Web (build production)

```bash
cd /workspaces/MASLIVE/app
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN=ton_token_ici
```

### Flutter Chrome (développement local)

```bash
cd /workspaces/MASLIVE/app
flutter run -d chrome \
  --dart-define=MAPBOX_ACCESS_TOKEN=ton_token_ici
```

## Fonctionnement

### 1. Code Dart (WebMapboxGLMap)

Le widget récupère le token depuis l'environnement :

```dart
const runtimeToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');
final tokenToUse = runtimeToken.isNotEmpty ? runtimeToken : widget.accessToken;
```

### 2. Bridge JavaScript (mapbox_bridge.js)

La fonction `initMapboxMap` accepte le token en paramètre :

```javascript
window.initMapboxMap = function(containerId, token = null, options = {}) {
  // Priorité: paramètre > options.accessToken > window.__MAPBOX_TOKEN__
  const accessToken = token || options.accessToken || window.__MAPBOX_TOKEN__;
  
  if (!accessToken || accessToken === 'YOUR_MAPBOX_TOKEN') {
    console.error('❌ Token Mapbox manquant ou invalide');
    console.info('💡 Passe le token via --dart-define=MAPBOX_ACCESS_TOKEN=ton_token');
    return null;
  }
  
  mapboxgl.accessToken = accessToken;
  // ...
}
```

### 3. index.html (fallback vide)

```html
<script>
  // Token Mapbox - OPTIONNEL : passe le via --dart-define=MAPBOX_ACCESS_TOKEN=ton_token
  // Laisse vide ou "" pour forcer l'utilisation de --dart-define uniquement
  window.__MAPBOX_TOKEN__ = "";
</script>
```

## Ordre de priorité

1. **`--dart-define=MAPBOX_ACCESS_TOKEN`** (recommandé)
2. `widget.accessToken` (paramètre du widget Flutter)
3. `window.__MAPBOX_TOKEN__` (fallback dans index.html)

## Avantages

✅ **Sécurité** : le token n'est jamais committé dans Git  
✅ **Flexibilité** : tokens différents par environnement (dev/staging/prod)  
✅ **CI/CD friendly** : facile à injecter dans les pipelines  
✅ **Pas de recompilation** : change le token sans toucher au code

## Utilisation avec Firebase Hosting

Dans ton script de déploiement :

```bash
#!/bin/bash
cd /workspaces/MASLIVE/app

# Récupérer le token depuis une variable d'environnement sécurisée
MAPBOX_TOKEN="${MAPBOX_ACCESS_TOKEN:-$MAPBOX_PUBLIC_TOKEN}"

if [ -z "$MAPBOX_TOKEN" ]; then
  echo "❌ MAPBOX_ACCESS_TOKEN non défini"
  exit 1
fi

# Build avec le token
flutter build web --release \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"

# Deploy
cd ..
firebase deploy --only hosting
```

## Exemple complet Codespaces

```bash
# Étape 1 : Définir le token en variable d'environnement
export MAPBOX_ACCESS_TOKEN="pk.eyJ1IjoibW9ucHNldWRvIiwiYSI6ImNsZjB1Z2p5dTBjZ3gzcHFsbGJ6ZGZpcGkifQ.xyz123"

# Étape 2 : Lancer l'app
cd /workspaces/MASLIVE/app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 \
  --dart-define=MAPBOX_ACCESS_TOKEN="$MAPBOX_ACCESS_TOKEN"
```

## Vérification

Si le token est manquant ou invalide, la console affichera :

```
❌ Token Mapbox manquant ou invalide
💡 Passe le token via --dart-define=MAPBOX_ACCESS_TOKEN=ton_token
```

## Migration depuis l'ancienne méthode

**Avant** (token en dur) :
```html
window.__MAPBOX_TOKEN__ = "pk.eyJ1...xyz";
```

**Après** (propre) :
```bash
flutter build web --dart-define=MAPBOX_ACCESS_TOKEN=pk.eyJ1...xyz
```

**Résultat** : même fonctionnement, sécurité améliorée ! 🎉
