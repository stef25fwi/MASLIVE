# Wizard Circuit — Test rapide “Style URL Mapbox”

Objectif : valider que le champ **“Style URL Mapbox (optionnel)”** recharge bien le style de carte dans le wizard (preview Step 1 + étapes périmètre/route/POIs) et que les overlays (POIs, tracé, markers) se ré-appliquent après changement.

## Styles Mapbox “connus” (copier/coller)
Ces valeurs sont des `styleUrl` compatibles Web + Mobile (URI Mapbox).

- `mapbox://styles/mapbox/streets-v12`
- `mapbox://styles/mapbox/outdoors-v12`
- `mapbox://styles/mapbox/satellite-streets-v12`
- `mapbox://styles/mapbox/light-v11`
- `mapbox://styles/mapbox/dark-v11`

## Style custom (le tien)
- Format : `mapbox://styles/<username>/<style-id>`
- Exemple : `mapbox://styles/moncompte/ckx123abc456def789ghi0`

## Procédure de test (1 minute)
1. Ouvre le wizard et reste sur l’écran “Informations de base”.
2. Dans **Style URL Mapbox**, colle `mapbox://styles/mapbox/streets-v12`.
3. Remplace par `mapbox://styles/mapbox/satellite-streets-v12`.
4. Attends ~0,5s après chaque collage (debounce) : la carte doit changer de style.
5. Va à l’étape “Périmètre” puis “Tracé” : le style doit être identique.
6. (Optionnel) Ajoute quelques points/POIs puis rechange le style : les POIs/tracés doivent réapparaître après le reload du style.

## Résultat attendu
- Le style visuel change après édition du champ (sans navigation).
- Le changement est conservé en avançant/reculant dans les étapes.
- Après un `setStyle`, les overlays reviennent automatiquement (POIs/layers, markers, polylines/polygons).

## Si ça ne marche pas
- Si la carte ne s’affiche pas : token Mapbox manquant/invalide (UI admin ou build `--dart-define=MAPBOX_ACCESS_TOKEN=...`).
- Si un style custom ne charge pas : token restreint / pas d’accès au style (403), ou style non public.
- Si Web seulement échoue : scripts Mapbox GL JS bloqués (adblock/réseau filtré) ; tester sur un autre navigateur/réseau.
