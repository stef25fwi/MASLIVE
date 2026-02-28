/**
 * Mapbox Bridge for Flutter Web
 * 
 * Ce fichier sert de pont entre Flutter Web et Mapbox GL JS.
 * Il permet à Flutter d'interagir avec la carte Mapbox via JavaScript.
 */

(function() {
  'use strict';

  // Stockage global de la carte et des managers
  window.MapboxBridge = {
    map: null,
    // Multi-cartes: association stable containerId -> map.
    // (Conserve `map` pour compat legacy, mais éviter de l'utiliser côté widgets modernes.)
    mapsByContainerId: new Map(),
    markers: new Map(),
    sources: new Map(),
    layers: new Map(),
    userMarker: null,
  };

  // Récupère une map par containerId si possible (sinon fallback legacy `map`).
  // Retourne l'instance Mapbox GL JS (ou null).
  window.MapboxBridge.getMap = function(containerId) {
    try {
      if (containerId && window.MapboxBridge.mapsByContainerId && window.MapboxBridge.mapsByContainerId.has(containerId)) {
        return window.MapboxBridge.mapsByContainerId.get(containerId);
      }
    } catch (_) {
      // ignore
    }
    return window.MapboxBridge.map;
  };

  /**
   * Initialise la carte Mapbox
   * @param {string} containerId - ID du conteneur HTML
   * @param {string|null} token - Token Mapbox (prioritaire sur window.__MAPBOX_TOKEN__)
   * @param {object} options - Options de configuration
   */
  window.initMapboxMap = function(containerId, token = null, options = {}) {
    // Priorité: paramètre > options.accessToken > window.__MAPBOX_TOKEN__
    const accessToken = token || options.accessToken || window.__MAPBOX_TOKEN__;
    const style = options.style || window.__MAPBOX_STYLE__ || 'mapbox://styles/mapbox/streets-v12';
    
    if (!accessToken || accessToken === 'YOUR_MAPBOX_TOKEN') {
      console.error('❌ Token Mapbox manquant ou invalide');
      console.info('💡 Passe le token via --dart-define=MAPBOX_ACCESS_TOKEN=ton_token');
      return null;
    }

    mapboxgl.accessToken = accessToken;

    const defaultOptions = {
      container: containerId,
      style: style,
      center: options.center || [-61.533, 16.241], // [lng, lat]
      zoom: options.zoom || 13,
      pitch: options.pitch || 45,
      bearing: options.bearing || 0,
      antialias: true,
    };

    try {
      const map = new mapboxgl.Map(defaultOptions);
      // Compat legacy: conserve un pointeur global, MAIS stocke aussi par container.
      window.MapboxBridge.map = map;
      try {
        window.MapboxBridge.mapsByContainerId.set(containerId, map);
      } catch (_) {
        // ignore
      }

      // Événements de chargement
      map.on('load', function() {
        console.log('✅ Mapbox GL JS map loaded');

        // Ajouter les contrôles de navigation 3D
        map.addControl(new mapboxgl.NavigationControl({
          visualizePitch: true
        }), 'top-right');

        // Ajouter le contrôle de géolocalisation
        const geolocate = new mapboxgl.GeolocateControl({
          positionOptions: {
            enableHighAccuracy: true
          },
          trackUserLocation: true,
          showUserHeading: true
        });
        map.addControl(geolocate, 'top-right');

        // Activer les bâtiments 3D par défaut
        if (options.enable3DBuildings !== false) {
          add3DBuildings(map);
        }

        // Callback vers Flutter si disponible.
        // NOTE: `load` = style prêt, mais les tuiles peuvent encore se charger.
        // On attend un état stable (idle/tiles) pour éviter que l'utilisateur
        // voie le chargement après le splash.
        let didNotify = false;
        const notify = () => {
          if (didNotify) return;
          didNotify = true;
          try {
            if (window.onMapboxReady) {
              window.onMapboxReady();
            }
          } catch (_) {}
        };
        const isStable = () => {
          try {
            const styleOk = (map.isStyleLoaded && map.isStyleLoaded() === true);
            const tilesOk = (typeof map.areTilesLoaded === 'function') ? (map.areTilesLoaded() === true) : true;
            return styleOk && tilesOk;
          } catch (_) {
            return false;
          }
        };
        if (isStable()) {
          notify();
        } else {
          const onIdle = () => {
            if (isStable()) {
              try { map.off('idle', onIdle); } catch (_) {}
              notify();
            }
          };
          try { map.on('idle', onIdle); } catch (_) {}
          // Fallback: ne jamais bloquer indéfiniment le callback legacy.
          setTimeout(() => { notify(); }, 8000);
        }
      });

      map.on('error', function(e) {
        console.error('❌ Mapbox error:', e);
      });

      // Nettoyage du registre multi-maps quand la map est détruite.
      try {
        map.on('remove', function() {
          try {
            if (window.MapboxBridge.mapsByContainerId && window.MapboxBridge.mapsByContainerId.get(containerId) === map) {
              window.MapboxBridge.mapsByContainerId.delete(containerId);
            }
          } catch (_) {}
        });
      } catch (_) {
        // ignore
      }

      return map;
    } catch (error) {
      console.error('❌ Erreur lors de l\'initialisation de Mapbox:', error);
      return null;
    }
  };

  /**
   * Ajoute les bâtiments 3D à la carte
   * @param {mapboxgl.Map} map - Instance de la carte
   */
  function add3DBuildings(map) {
    // Attendre que le style soit chargé
    if (!map.isStyleLoaded()) {
      map.on('style.load', () => add3DBuildings(map));
      return;
    }

    // Vérifier si la source 'composite' existe
    if (!map.getSource('composite')) {
      console.warn('⚠️ Source "composite" non disponible pour les bâtiments 3D');
      return;
    }

    const layerId = 'maslive-3d-buildings';
    
    // Supprimer le layer s'il existe déjà
    if (map.getLayer(layerId)) {
      map.removeLayer(layerId);
    }

    // Ajouter le layer 3D
    map.addLayer({
      'id': layerId,
      'source': 'composite',
      'source-layer': 'building',
      'filter': ['==', 'extrude', 'true'],
      'type': 'fill-extrusion',
      'minzoom': 14.5,
      'paint': {
        'fill-extrusion-color': '#D1D5DB',
        'fill-extrusion-height': [
          'interpolate',
          ['linear'],
          ['zoom'],
          15, 0,
          15.05, ['get', 'height']
        ],
        'fill-extrusion-base': [
          'interpolate',
          ['linear'],
          ['zoom'],
          15, 0,
          15.05, ['get', 'min_height']
        ],
        'fill-extrusion-opacity': 0.7
      }
    });

    console.log('✅ Bâtiments 3D ajoutés');
  }

  /**
   * Centre la carte sur une position
   * @param {number} lng - Longitude
   * @param {number} lat - Latitude
   * @param {number} zoom - Niveau de zoom (optionnel)
   */
  window.flyToPosition = function(lng, lat, zoom = 15.5) {
    const map = window.MapboxBridge.map;
    if (!map) return;

    map.flyTo({
      center: [lng, lat],
      zoom: zoom,
      pitch: 45,
      duration: 1000
    });
  };

  /**
   * Ajoute ou met à jour le marqueur utilisateur
   * @param {number} lng - Longitude
   * @param {number} lat - Latitude
   */
  window.updateUserMarker = function(lng, lat) {
    const map = window.MapboxBridge.map;
    if (!map) return;

    // Supprimer l'ancien marqueur
    if (window.MapboxBridge.userMarker) {
      window.MapboxBridge.userMarker.remove();
    }

    // Créer un nouveau marqueur
    const el = document.createElement('div');
    el.className = 'user-location-marker';
    el.style.width = '24px';
    el.style.height = '24px';
    el.style.borderRadius = '50%';
    el.style.backgroundColor = '#4285F4';
    el.style.border = '3px solid white';
    el.style.boxShadow = '0 2px 6px rgba(0,0,0,0.3)';

    const marker = new mapboxgl.Marker(el)
      .setLngLat([lng, lat])
      .addTo(map);

    window.MapboxBridge.userMarker = marker;
  };

  /**
   * Ajoute un marqueur personnalisé
   * @param {string} id - Identifiant unique du marqueur
   * @param {number} lng - Longitude
   * @param {number} lat - Latitude
   * @param {object} options - Options du marqueur
   */
  window.addMarker = function(id, lng, lat, options = {}) {
    const map = window.MapboxBridge.map;
    if (!map) return;

    // Supprimer le marqueur existant
    if (window.MapboxBridge.markers.has(id)) {
      window.MapboxBridge.markers.get(id).remove();
    }

    const marker = new mapboxgl.Marker(options)
      .setLngLat([lng, lat])
      .addTo(map);

    window.MapboxBridge.markers.set(id, marker);
  };

  /**
   * Supprime un marqueur
   * @param {string} id - Identifiant du marqueur
   */
  window.removeMarker = function(id) {
    if (window.MapboxBridge.markers.has(id)) {
      window.MapboxBridge.markers.get(id).remove();
      window.MapboxBridge.markers.delete(id);
    }
  };

  /**
   * Change le style de la carte
   * @param {string} styleUrl - URL du style Mapbox
   */
  window.setMapStyle = function(styleUrl) {
    const map = window.MapboxBridge.map;
    if (!map) return;

    map.setStyle(styleUrl);
    
    // Réappliquer les bâtiments 3D après le chargement du style
    map.once('style.load', function() {
      add3DBuildings(map);
    });
  };

  /**
   * Ajuste la vue de la carte sur des bounds
   * @param {array} bounds - [[minLng, minLat], [maxLng, maxLat]]
   */
  window.fitBounds = function(bounds, options = {}) {
    const map = window.MapboxBridge.map;
    if (!map) return;

    const defaultOptions = {
      padding: 50,
      pitch: 45,
      duration: 1000
    };

    map.fitBounds(bounds, { ...defaultOptions, ...options });
  };

  /**
   * Fixe des bounds maximum pour le déplacement de la carte
   * @param {array|null} bounds - [[minLng, minLat], [maxLng, maxLat]] ou null pour désactiver
   */
  window.setMaxBounds = function(bounds) {
    const map = window.MapboxBridge.map;
    if (!map) return;

    try {
      if (!bounds) {
        map.setMaxBounds(null);
        return;
      }
      map.setMaxBounds(bounds);
    } catch (e) {
      console.error('❌ Erreur setMaxBounds:', e);
    }
  };

  /**
   * Redimensionne la carte (utile après un resize du container)
   */
  window.resizeMap = function() {
    const map = window.MapboxBridge.map;
    if (!map) return;
    
    map.resize();
  };

  /**
   * Nettoie et détruit la carte
   */
  window.destroyMap = function() {
    const map = window.MapboxBridge.map;
    if (!map) return;

    // Supprimer tous les marqueurs
    window.MapboxBridge.markers.forEach(marker => marker.remove());
    window.MapboxBridge.markers.clear();
    
    if (window.MapboxBridge.userMarker) {
      window.MapboxBridge.userMarker.remove();
    }

    // Détruire la carte
    map.remove();
    window.MapboxBridge.map = null;
  };

  // ============================================================
  // MasliveMapboxV2: API "WASM-friendly" (Dart <-> JS)
  // - Pas de callbacks Dart passés à JS
  // - Communication par postMessage(JSON.stringify(...))
  // - Manipulation de la carte via containerId + JSON
  // ============================================================

  const _v2State = new Map(); // containerId -> { map, markers: Map<string, Marker>, routeAnim }

  function _postToFlutter(obj) {
    try {
      window.postMessage(JSON.stringify(obj), '*');
    } catch (e) {
      // ignore
    }
  }

  function _getMap(containerId) {
    const state = _v2State.get(containerId);
    return state ? state.map : null;
  }

  function _ensureState(containerId, map) {
    if (_v2State.has(containerId)) return _v2State.get(containerId);
    const state = {
      map,
      markers: new Map(),
      routeAnim: null,
      lastErrorKey: null,
      lastErrorAt: 0,
    };
    _v2State.set(containerId, state);
    return state;
  }

  function _classifyRuntimeError(raw) {
    let msg = '';
    let status = null;
    try {
      if (raw && typeof raw === 'object') {
        if (typeof raw.status === 'number') status = raw.status;
        if (raw.response && typeof raw.response.status === 'number') status = raw.response.status;
      }
    } catch (_) {
      // ignore
    }
    try {
      if (raw && raw.message) msg = String(raw.message);
      else msg = String(raw);
    } catch (_) {
      msg = '';
    }

    const lower = (msg || '').toLowerCase();

    // Style URL invalide: HTML (doctype) renvoyé au lieu du JSON de style.
    // Typiquement causé par un lien Mapbox Studio (page /edit) collé à la place de
    // `mapbox://styles/<user>/<styleId>` ou d'une URL API styles/v1.
    if (
      lower.includes('unexpected token <') ||
      lower.includes('<!doctype') ||
      lower.includes('doctype') ||
      (lower.includes('not valid json') && (lower.includes('json') || lower.includes('style')))
    ) {
      return {
        reason: 'STYLE_NOT_JSON',
        message:
          'URL de style invalide: la réponse ressemble à du HTML (pas du JSON). ' +
          'Si tu as collé un lien Mapbox Studio, utilise `mapbox://styles/<user>/<styleId>`.' +
          (msg ? ' (' + msg + ')' : ''),
      };
    }

    // Token invalide / révoqué
    if (
      status === 401 ||
      lower.includes('401') ||
      lower.includes('unauthorized') ||
      lower.includes('invalid token') ||
      lower.includes('invalid access token') ||
      lower.includes('access token is invalid')
    ) {
      return {
        reason: 'TOKEN_INVALID',
        message: 'Token Mapbox invalide ou révoqué. Vérifie le token (pk.*) et rebuild/deploy.' + (msg ? ' (' + msg + ')' : ''),
      };
    }

    // Token valide mais non autorisé (scopes, restrictions, style privé, etc.)
    if (
      status === 403 ||
      lower.includes('403') ||
      lower.includes('forbidden') ||
      lower.includes('not authorized')
    ) {
      return {
        reason: 'TOKEN_FORBIDDEN',
        message: 'Accès Mapbox refusé (403). Vérifie les permissions/restrictions du token et l\'accès au style.' + (msg ? ' (' + msg + ')' : ''),
      };
    }

    // Requêtes bloquées (adblock, DNS filtré, corporate proxy)
    if (
      lower.includes('failed to fetch') ||
      lower.includes('networkerror') ||
      lower.includes('err_blocked_by_client') ||
      lower.includes('blocked')
    ) {
      return {
        reason: 'NETWORK_BLOCKED',
        message: 'Requêtes Mapbox bloquées (réseau ou bloqueur). Autorise api.mapbox.com/unpkg.com et réessaie.' + (msg ? ' (' + msg + ')' : ''),
      };
    }

    // WebGL (rare en runtime, mais possible si contexte perdu)
    if (lower.includes('webgl')) {
      return {
        reason: 'WEBGL_UNSUPPORTED',
        message: 'WebGL indisponible: Mapbox GL JS ne peut pas fonctionner sur cet appareil/navigateur.' + (msg ? ' (' + msg + ')' : ''),
      };
    }

    return {
      reason: 'MAPBOX_RUNTIME_ERROR',
      message: 'Erreur Mapbox: ' + (msg || 'inconnue'),
    };
  }

  function _parseBool(v, fallback) {
    if (typeof v === 'boolean') return v;
    if (typeof v === 'string') {
      if (v.toLowerCase() === 'true') return true;
      if (v.toLowerCase() === 'false') return false;
    }
    return fallback;
  }

  function _clampNumber(n, min, max, fallback) {
    const x = Number(n);
    if (!isFinite(x)) return fallback;
    return Math.max(min, Math.min(max, x));
  }

  function _removeLayerIfExists(map, layerId) {
    try {
      if (map.getLayer && map.getLayer(layerId)) {
        map.removeLayer(layerId);
      }
    } catch (_) {
      // ignore
    }
  }

  function _removeSourceIfExists(map, sourceId) {
    try {
      if (map.getSource && map.getSource(sourceId)) {
        map.removeSource(sourceId);
      }
    } catch (_) {
      // ignore
    }
  }

  function _ensureArrowImage(map) {
    try {
      if (map.hasImage && map.hasImage('maslive_arrow')) return;
      const canvas = document.createElement('canvas');
      canvas.width = 64;
      canvas.height = 64;
      const ctx = canvas.getContext('2d');
      ctx.clearRect(0, 0, 64, 64);
      ctx.fillStyle = 'white';
      ctx.beginPath();
      ctx.moveTo(18, 32);
      ctx.lineTo(46, 18);
      ctx.lineTo(46, 46);
      ctx.closePath();
      ctx.fill();
      map.addImage('maslive_arrow', ctx.getImageData(0, 0, 64, 64), { sdf: false });
    } catch (_) {
      // ignore
    }
  }

  function _removeRouteLayersAndSource(map) {
    _removeLayerIfExists(map, 'maslive_polyline_center');
    _removeLayerIfExists(map, 'maslive_polyline_core');
    _removeLayerIfExists(map, 'maslive_polyline_casing');
    _removeLayerIfExists(map, 'maslive_polyline_glow');
    _removeLayerIfExists(map, 'maslive_polyline_shadow');
    _removeLayerIfExists(map, 'maslive_polyline_arrows');
    _removeLayerIfExists(map, 'maslive_polyline_layer');
    _removeSourceIfExists(map, 'maslive_polyline');
    _removeSourceIfExists(map, 'maslive_polyline_segments');
  }

  function _stopRouteAnimation(state) {
    try {
      if (!state || !state.routeAnim) return;
      const ra = state.routeAnim;
      state.routeAnim = null;
      if (ra.timer) {
        clearInterval(ra.timer);
      }
      if (ra.marker) {
        try { ra.marker.remove(); } catch (_) {}
      }
    } catch (_) {
      // ignore
    }
  }

  function _startRouteAnimation(state, coords, speed) {
    if (!state || !state.map) return;
    const map = state.map;

    _stopRouteAnimation(state);
    if (!coords || coords.length < 2) return;

    const segLens = [];
    let total = 0;
    for (let i = 0; i < coords.length - 1; i++) {
      const a = coords[i];
      const b = coords[i + 1];
      const dx = b[0] - a[0];
      const dy = b[1] - a[1];
      const len = Math.sqrt(dx * dx + dy * dy);
      segLens.push(len);
      total += len;
    }
    if (total <= 0) return;

    const el = document.createElement('div');
    el.style.width = '10px';
    el.style.height = '10px';
    el.style.borderRadius = '50%';
    el.style.background = 'white';
    el.style.border = '2px solid rgba(0,0,0,0.35)';
    const marker = new mapboxgl.Marker({ element: el }).setLngLat(coords[0]).addTo(map);

    const s = _clampNumber(speed, 0.1, 10.0, 1.0);
    let t = 0;
    const timer = setInterval(() => {
      try {
        t += 0.0025 * s;
        if (t > 1) t -= 1;
        let dist = t * total;
        let idx = 0;
        while (idx < segLens.length && dist > segLens[idx]) {
          dist -= segLens[idx];
          idx++;
        }
        if (idx >= segLens.length) idx = segLens.length - 1;
        const a = coords[idx];
        const b = coords[idx + 1];
        const seg = segLens[idx] || 1;
        const u = dist / seg;
        const lng = a[0] + (b[0] - a[0]) * u;
        const lat = a[1] + (b[1] - a[1]) * u;
        marker.setLngLat([lng, lat]);
      } catch (_) {
        // ignore
      }
    }, 33);

    state.routeAnim = { timer, marker };
  }

  window.MasliveMapboxV2 = {
    init: function(containerId, token, optionsJson) {
      try {
        const options = optionsJson ? JSON.parse(optionsJson) : {};
        // Diagnostics précoces (permet à Flutter d'afficher un message utile).
        try {
          if (!containerId || String(containerId).trim().length === 0) {
            _postToFlutter({
              type: 'MASLIVE_MAP_ERROR',
              containerId: containerId || '',
              reason: 'CONTAINER_ID_MISSING',
              message: 'ContainerId manquant pour la carte.',
            });
            return false;
          }

          const el = document.getElementById(containerId);
          if (!el) {
            _postToFlutter({
              type: 'MASLIVE_MAP_ERROR',
              containerId,
              reason: 'CONTAINER_NOT_FOUND',
              message: 'Conteneur HTML introuvable (DOM).',
            });
            return false;
          }

          if (typeof mapboxgl === 'undefined') {
            let status = '';
            try {
              status = (window.__MAPBOXGL_LOAD_STATUS__ ? String(window.__MAPBOXGL_LOAD_STATUS__) : '');
            } catch (_) {
              status = '';
            }
            let hint = '';
            const st = (status || '').toLowerCase();
            if (st.startsWith('error')) {
              hint = ' (échec de chargement du script Mapbox GL JS: bloqué par adblock/DNS, ou réseau)';
            } else if (st.startsWith('loading')) {
              hint = ' (script Mapbox GL JS encore en chargement)';
            } else if (st.startsWith('loaded')) {
              hint = ' (script déclaré chargé, mais mapboxgl absent: bloqueur/extension possible)';
            }
            _postToFlutter({
              type: 'MASLIVE_MAP_ERROR',
              containerId,
              reason: 'MAPBOXGL_MISSING',
              message: 'Mapbox GL JS non chargé (scripts https://api.mapbox.com potentiellement bloqués). Status=' + status + hint,
            });
            return false;
          }

          // Vérifie WebGL (Mapbox GL JS ne fonctionne pas sans WebGL).
          try {
            if (mapboxgl.supported && mapboxgl.supported() !== true) {
              _postToFlutter({
                type: 'MASLIVE_MAP_ERROR',
                containerId,
                reason: 'WEBGL_UNSUPPORTED',
                message: 'WebGL indisponible: Mapbox GL JS ne peut pas s\'initialiser sur ce navigateur/appareil.',
              });
              return false;
            }
          } catch (_) {
            // ignore
          }

          // Token manquant (même logique que initMapboxMap).
          const accessToken = token || options.accessToken || window.__MAPBOX_TOKEN__;
          if (!accessToken || accessToken === 'YOUR_MAPBOX_TOKEN') {
            _postToFlutter({
              type: 'MASLIVE_MAP_ERROR',
              containerId,
              reason: 'TOKEN_MISSING',
              message: 'Token Mapbox manquant ou invalide.',
            });
            return false;
          }
        } catch (_) {
          // ignore
        }
        const map = window.initMapboxMap(containerId, token, options);
        if (!map) {
          _postToFlutter({
            type: 'MASLIVE_MAP_ERROR',
            containerId,
            reason: 'INIT_FAILED',
            message: 'Initialisation Mapbox GL JS échouée (voir console navigateur pour le détail).',
          });
          return false;
        }

        const state = _ensureState(containerId, map);
        state.map = map;

        // Signal "READY" uniquement quand la carte est vraiment stable
        // (style + tuiles visibles), pour que le splash masque le chargement.
        let didPostReady = false;
        const postReady = () => {
          if (didPostReady) return;
          didPostReady = true;
          _postToFlutter({ type: 'MASLIVE_MAP_READY', containerId });
        };
        const isStable = () => {
          try {
            const styleOk = (map.isStyleLoaded && map.isStyleLoaded() === true);
            const tilesOk = (typeof map.areTilesLoaded === 'function') ? (map.areTilesLoaded() === true) : true;
            return styleOk && tilesOk;
          } catch (_) {
            return false;
          }
        };

        map.on('load', function() {
          if (isStable()) {
            postReady();
            return;
          }

          const onIdle = function() {
            if (!isStable()) return;
            try { map.off('idle', onIdle); } catch (_) {}
            postReady();
          };
          try { map.on('idle', onIdle); } catch (_) {}

          // Fallback: si l'événement idle ne survient pas (sources dynamiques),
          // on signale quand même après un délai.
          setTimeout(() => { postReady(); }, 8000);
        });

        // Remonte les erreurs runtime (ex: style/tiles/token) vers Flutter.
        // On évite de spammer via un petit throttle/dédoublonnage.
        try {
          map.on('error', function(e) {
            try {
              const raw = (e && (e.error || e)) ? (e.error || e) : e;
              const c = _classifyRuntimeError(raw);

              const now = Date.now();
              const key = String(c.reason || '') + '|' + String(c.message || '');
              try {
                const st = _v2State.get(containerId);
                if (st) {
                  const lastKey = st.lastErrorKey;
                  const lastAt = Number(st.lastErrorAt || 0);
                  if (lastKey === key && (now - lastAt) < 2000) {
                    return;
                  }
                  st.lastErrorKey = key;
                  st.lastErrorAt = now;
                }
              } catch (_) {
                // ignore
              }

              _postToFlutter({
                type: 'MASLIVE_MAP_ERROR',
                containerId,
                reason: c.reason,
                message: c.message,
              });
            } catch (_) {
              // ignore
            }
          });
        } catch (_) {
          // ignore
        }

        map.on('click', function(e) {
          try {
            if (!e || !e.lngLat) return;
            _postToFlutter({
              type: 'MASLIVE_MAP_TAP',
              containerId,
              lng: e.lngLat.lng,
              lat: e.lngLat.lat,
            });
          } catch (_) {
            // ignore
          }
        });

        return true;
      } catch (e) {
        console.error('❌ MasliveMapboxV2.init error:', e);
        try {
          _postToFlutter({
            type: 'MASLIVE_MAP_ERROR',
            containerId: containerId || '',
            reason: 'EXCEPTION',
            message: 'Erreur JS pendant l\'initialisation Mapbox: ' + String(e),
          });
        } catch (_) {
          // ignore
        }
        return false;
      }
    },

    moveTo: function(containerId, lng, lat, zoom, animate) {
      const map = _getMap(containerId);
      if (!map) return;
      try {
        if (animate) {
          map.flyTo({ center: [lng, lat], zoom: zoom });
        } else {
          map.jumpTo({ center: [lng, lat], zoom: zoom });
        }
      } catch (e) {
        console.error('❌ MasliveMapboxV2.moveTo error:', e);
      }
    },

    resize: function(containerId) {
      const map = _getMap(containerId);
      if (!map) return;
      try {
        map.resize();
      } catch (e) {
        console.error('❌ MasliveMapboxV2.resize error:', e);
      }
    },

    setStyle: function(containerId, styleUrl) {
      const map = _getMap(containerId);
      if (!map) return;
      try {
        map.setStyle(styleUrl);
      } catch (e) {
        console.error('❌ MasliveMapboxV2.setStyle error:', e);
      }
    },

    setMarkers: function(containerId, markersJson) {
      const state = _v2State.get(containerId);
      const map = state ? state.map : null;
      if (!map) return;
      try {
        // Remove old markers
        state.markers.forEach((marker) => {
          try { marker.remove(); } catch (_) {}
        });
        state.markers.clear();

        const markers = markersJson ? JSON.parse(markersJson) : [];
        for (const m of markers) {
          const el = document.createElement('div');
          const size = (Number(m.size || 1) * 20);
          el.style.width = size + 'px';
          el.style.height = size + 'px';
          el.style.backgroundColor = String(m.color || '#FF0000');
          el.style.borderRadius = '50%';
          el.style.border = '2px solid white';

          // Label (numéro, etc.)
          const label = (m.label === null || m.label === undefined) ? '' : String(m.label);
          if (label && label.length > 0) {
            el.style.display = 'flex';
            el.style.alignItems = 'center';
            el.style.justifyContent = 'center';
            el.style.color = '#000';
            el.style.fontSize = Math.max(10, Math.floor(size * 0.55)) + 'px';
            el.style.fontWeight = '700';
            el.style.textShadow = '0 0 2px rgba(255,255,255,0.9)';
            el.textContent = label;
          }

          const marker = new mapboxgl.Marker({ element: el })
            .setLngLat([Number(m.lng), Number(m.lat)])
            .addTo(map);
          state.markers.set(String(m.id || ''), marker);
        }
      } catch (e) {
        console.error('❌ MasliveMapboxV2.setMarkers error:', e);
      }
    },

    fitBounds: function(containerId, west, south, east, north, padding, animate) {
      const map = _getMap(containerId);
      if (!map) return;
      try {
        const bounds = [[Number(west), Number(south)], [Number(east), Number(north)]];
        const options = {
          padding: Number(padding || 48),
          duration: animate ? 900 : 0,
        };
        map.fitBounds(bounds, options);
      } catch (e) {
        console.error('❌ MasliveMapboxV2.fitBounds error:', e);
      }
    },

    setMaxBounds: function(containerId, boundsJson) {
      const map = _getMap(containerId);
      if (!map) return;
      try {
        if (!boundsJson) {
          map.setMaxBounds(null);
          return;
        }
        const b = JSON.parse(boundsJson);
        // b: [[west,south],[east,north]]
        map.setMaxBounds(b);
      } catch (e) {
        console.error('❌ MasliveMapboxV2.setMaxBounds error:', e);
      }
    },

    getCenter: function(containerId) {
      const map = _getMap(containerId);
      if (!map) return null;
      try {
        const c = map.getCenter();
        return JSON.stringify({ lng: c.lng, lat: c.lat, zoom: map.getZoom() });
      } catch (e) {
        console.error('❌ MasliveMapboxV2.getCenter error:', e);
        return null;
      }
    },

    setPolyline: function(containerId, pointsJson, colorHex, width, show, optionsJson) {
      const state = _v2State.get(containerId);
      const map = state ? state.map : null;
      if (!map) return;
      const sourceId = 'maslive_polyline';
      const segmentsSourceId = 'maslive_polyline_segments';

      try {
        if (!show) {
          _stopRouteAnimation(state);
          _removeRouteLayersAndSource(map);
          return;
        }

        const opts = optionsJson ? JSON.parse(optionsJson) : {};
        const roadLike = _parseBool(opts.roadLike, true);
        const shadow3d = _parseBool(opts.shadow3d, true);
        const showDirection = _parseBool(opts.showDirection, true);
        const animateDirection = _parseBool(opts.animateDirection, false);
        const animationSpeed = _clampNumber(opts.animationSpeed, 0.1, 10.0, 1.0);

        const opacity = _clampNumber(opts.opacity, 0.0, 1.0, 1.0);
        const casingWidthOpt = Number(opts.casingWidth || 0);
        const casingColorOpt = String(opts.casingColor || 'rgba(0,0,0,0.45)');
        const glowEnabled = _parseBool(opts.glowEnabled, false);
        const glowWidth = Number(opts.glowWidth || 0);
        const glowOpacity = _clampNumber(opts.glowOpacity, 0.0, 1.0, 0.0);
        const glowBlur = Number(opts.glowBlur || 0);
        const glowColor = String(opts.glowColor || colorHex || '#1A73E8');
        const dashArray = Array.isArray(opts.dashArray) ? opts.dashArray : null;
        const lineCap = (opts.lineCap === 'butt' || opts.lineCap === 'square' || opts.lineCap === 'round') ? opts.lineCap : 'round';
        const lineJoin = (opts.lineJoin === 'bevel' || opts.lineJoin === 'miter' || opts.lineJoin === 'round') ? opts.lineJoin : 'round';
        const elevationPx = _clampNumber(opts.elevationPx, 0.0, 40.0, 0.0);
        const lineTranslate = (elevationPx > 0.01) ? [0, -elevationPx] : null;

        // Optionnel: rendu par segments (FeatureCollection) pour styles avancés.
        let segmentsFc = null;
        try {
          if (typeof opts.segmentsGeoJson === 'string' && opts.segmentsGeoJson.trim()) {
            const decoded = JSON.parse(opts.segmentsGeoJson);
            if (decoded && decoded.type === 'FeatureCollection' && Array.isArray(decoded.features)) {
              segmentsFc = decoded;
            }
          }
        } catch (_) {
          segmentsFc = null;
        }

        const points = pointsJson ? JSON.parse(pointsJson) : [];
        const coords = points.map((p) => [Number(p.lng), Number(p.lat)]);
        const geojson = {
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: coords },
        };

        const src = map.getSource(sourceId);
        if (!src) {
          map.addSource(sourceId, { type: 'geojson', data: geojson });
        } else {
          src.setData(geojson);
        }

        // Segments source (optionnel)
        const segSrc = map.getSource(segmentsSourceId);
        if (segmentsFc) {
          if (!segSrc) {
            map.addSource(segmentsSourceId, { type: 'geojson', data: segmentsFc });
          } else {
            segSrc.setData(segmentsFc);
          }
        } else {
          // Nettoyage si on repasse en mode “plein”
          _removeSourceIfExists(map, segmentsSourceId);
        }

        // Recréer les couches pour refléter le style
        _removeLayerIfExists(map, 'maslive_polyline_center');
        _removeLayerIfExists(map, 'maslive_polyline_core');
        _removeLayerIfExists(map, 'maslive_polyline_casing');
        _removeLayerIfExists(map, 'maslive_polyline_glow');
        _removeLayerIfExists(map, 'maslive_polyline_shadow');
        _removeLayerIfExists(map, 'maslive_polyline_arrows');
        _removeLayerIfExists(map, 'maslive_polyline_layer');

        const w = Number(width || 6);
        const mainColor = String(colorHex || '#1A73E8');

        const mainSource = segmentsFc ? segmentsSourceId : sourceId;
        const mainLineColor = segmentsFc ? ['get', 'color'] : mainColor;
        const mainLineWidth = segmentsFc ? ['get', 'width'] : w;
        const mainLineOpacity = segmentsFc ? ['get', 'opacity'] : opacity;

        // Zoom-aware width:
        // Quand on dézoome, une largeur en pixels constante devient visuellement
        // plus large que les routes du style Mapbox (effet "trop épais").
        // IMPORTANT: Mapbox n'autorise ['zoom'] qu'en entrée d'une expression
        // top-level 'step'/'interpolate'. Donc on génère directement une
        // expression line-width de type 'interpolate' (top-level).
        // - activé par défaut pour roadLike et pour le rendu par segments (Style Pro)
        const scaleWidthWithZoom = _parseBool(opts.scaleWidthWithZoom, (roadLike || !!segmentsFc));
        const scaledWidthExpr = (baseExpr) => {
          if (!scaleWidthWithZoom) return baseExpr;
          return ['interpolate', ['linear'], ['zoom'],
            10, ['*', baseExpr, 0.30],
            12, ['*', baseExpr, 0.50],
            14, ['*', baseExpr, 0.80],
            16, baseExpr,
            22, baseExpr,
          ];
        };
        const scaledWidthExprClampedMin = (baseExpr, minVal) => {
          if (!scaleWidthWithZoom) return baseExpr;
          return ['interpolate', ['linear'], ['zoom'],
            10, ['max', minVal, ['*', baseExpr, 0.30]],
            12, ['max', minVal, ['*', baseExpr, 0.50]],
            14, ['max', minVal, ['*', baseExpr, 0.80]],
            16, ['max', minVal, baseExpr],
            22, ['max', minVal, baseExpr],
          ];
        };
        const mainLineWidthScaled = scaledWidthExpr(mainLineWidth);

        if (!roadLike) {
          map.addLayer({
            id: 'maslive_polyline_layer',
            type: 'line',
            source: mainSource,
            layout: {
              'line-cap': lineCap,
              'line-join': lineJoin,
            },
            paint: {
              'line-width': mainLineWidthScaled,
              'line-color': mainLineColor,
              'line-opacity': mainLineOpacity,
              ...(lineTranslate ? { 'line-translate': lineTranslate, 'line-translate-anchor': 'map' } : {}),
            },
          });
        } else {
          if (shadow3d) {
            map.addLayer({
              id: 'maslive_polyline_shadow',
              type: 'line',
              source: sourceId,
              layout: {
                'line-cap': lineCap,
                'line-join': lineJoin,
              },
              paint: {
                'line-width': scaledWidthExpr(w + 8),
                'line-color': 'rgba(0,0,0,0.25)',
                'line-blur': 1.2,
                'line-opacity': opacity,
                ...(lineTranslate ? { 'line-translate': lineTranslate, 'line-translate-anchor': 'map' } : {}),
              },
            });
          }

          if (glowEnabled && (glowWidth > 0 || glowBlur > 0) && glowOpacity > 0) {
            map.addLayer({
              id: 'maslive_polyline_glow',
              type: 'line',
              source: sourceId,
              layout: {
                'line-cap': lineCap,
                'line-join': lineJoin,
              },
              paint: {
                'line-width': scaledWidthExpr(w + Math.max(0, glowWidth)),
                'line-color': glowColor,
                'line-opacity': glowOpacity,
                'line-blur': Math.max(0, glowBlur),
                ...(lineTranslate ? { 'line-translate': lineTranslate, 'line-translate-anchor': 'map' } : {}),
              },
            });
          }

          const casingWidth = (casingWidthOpt && casingWidthOpt > 0) ? casingWidthOpt : (w + 5);

          map.addLayer({
            id: 'maslive_polyline_casing',
            type: 'line',
            source: sourceId,
            layout: {
              'line-cap': lineCap,
              'line-join': lineJoin,
            },
            paint: {
              'line-width': scaledWidthExpr(casingWidth),
              'line-color': casingColorOpt,
              'line-opacity': opacity,
              ...(lineTranslate ? { 'line-translate': lineTranslate, 'line-translate-anchor': 'map' } : {}),
            },
          });

          map.addLayer({
            id: 'maslive_polyline_core',
            type: 'line',
            source: mainSource,
            layout: {
              'line-cap': lineCap,
              'line-join': lineJoin,
            },
            paint: {
              'line-width': mainLineWidthScaled,
              'line-color': mainLineColor,
              'line-opacity': mainLineOpacity,
              ...(lineTranslate ? { 'line-translate': lineTranslate, 'line-translate-anchor': 'map' } : {}),
            },
          });

          // Sur un rendu segmenté (multi-couleurs), on évite la "center line" blanche
          // pour rester proche du rendu natif (segments) et ne pas dégrader la lisibilité.
          if (!segmentsFc) {
            const centerBaseWidth = Math.max(1, Math.min(w, w * 0.33));
            map.addLayer({
              id: 'maslive_polyline_center',
              type: 'line',
              source: sourceId,
              layout: {
                'line-cap': lineCap,
                'line-join': lineJoin,
              },
              paint: {
                'line-width': scaledWidthExprClampedMin(centerBaseWidth, 1),
                'line-color': 'rgba(255,255,255,0.85)',
                'line-opacity': opacity,
                ...(lineTranslate ? { 'line-translate': lineTranslate, 'line-translate-anchor': 'map' } : {}),
              },
            });
          }
        }

        if (dashArray && dashArray.length >= 2) {
          const dash = [Number(dashArray[0]), Number(dashArray[1])];
          try {
            if (map.getLayer('maslive_polyline_layer')) {
              map.setPaintProperty('maslive_polyline_layer', 'line-dasharray', dash);
            }
            if (map.getLayer('maslive_polyline_core')) {
              map.setPaintProperty('maslive_polyline_core', 'line-dasharray', dash);
            }
          } catch (_) {
            // ignore
          }
        } else {
          try {
            if (map.getLayer('maslive_polyline_layer')) {
              map.setPaintProperty('maslive_polyline_layer', 'line-dasharray', null);
            }
            if (map.getLayer('maslive_polyline_core')) {
              map.setPaintProperty('maslive_polyline_core', 'line-dasharray', null);
            }
          } catch (_) {
            // ignore
          }
        }

        if (showDirection) {
          _ensureArrowImage(map);
          map.addLayer({
            id: 'maslive_polyline_arrows',
            type: 'symbol',
            source: sourceId,
            layout: {
              'symbol-placement': 'line',
              'symbol-spacing': 120,
              'icon-image': 'maslive_arrow',
              'icon-size': 0.35,
              'icon-allow-overlap': true,
              'icon-rotation-alignment': 'map',
            },
          });
        }

        if (animateDirection) {
          _startRouteAnimation(state, coords, animationSpeed);
        } else {
          _stopRouteAnimation(state);
        }
      } catch (e) {
        console.error('❌ MasliveMapboxV2.setPolyline error:', e);
      }
    },

    setPolygon: function(containerId, pointsJson, fillColorHex, fillOpacity, strokeColorHex, strokeWidth, show) {
      const map = _getMap(containerId);
      if (!map) return;
      const sourceId = 'maslive_polygon';
      const fillLayerId = 'maslive_polygon_fill';
      const lineLayerId = 'maslive_polygon_line';

      try {
        if (!show) {
          _removeLayerIfExists(map, lineLayerId);
          _removeLayerIfExists(map, fillLayerId);
          _removeSourceIfExists(map, sourceId);
          return;
        }

        const points = pointsJson ? JSON.parse(pointsJson) : [];
        const ring = points.map((p) => [Number(p.lng), Number(p.lat)]);
        const geojson = {
          type: 'Feature',
          geometry: { type: 'Polygon', coordinates: [ring] },
        };

        const src = map.getSource(sourceId);
        if (!src) {
          map.addSource(sourceId, { type: 'geojson', data: geojson });
          map.addLayer({
            id: fillLayerId,
            type: 'fill',
            source: sourceId,
            paint: {
              'fill-color': String(fillColorHex || '#FF0000'),
              'fill-opacity': Number(fillOpacity ?? 0.3),
            },
          });
          map.addLayer({
            id: lineLayerId,
            type: 'line',
            source: sourceId,
            paint: {
              'line-width': Number(strokeWidth || 2),
              'line-color': String(strokeColorHex || '#FF0000'),
            },
          });
        } else {
          src.setData(geojson);
        }
      } catch (e) {
        console.error('❌ MasliveMapboxV2.setPolygon error:', e);
      }
    },

    clearAll: function(containerId) {
      const state = _v2State.get(containerId);
      const map = state ? state.map : null;
      if (!map) return;
      try {
        _stopRouteAnimation(state);
        // markers
        state.markers.forEach((marker) => {
          try { marker.remove(); } catch (_) {}
        });
        state.markers.clear();

        // layers/sources
        _removeLayerIfExists(map, 'maslive_polyline_center');
        _removeLayerIfExists(map, 'maslive_polyline_core');
        _removeLayerIfExists(map, 'maslive_polyline_casing');
        _removeLayerIfExists(map, 'maslive_polyline_glow');
        _removeLayerIfExists(map, 'maslive_polyline_shadow');
        _removeLayerIfExists(map, 'maslive_polyline_arrows');
        _removeLayerIfExists(map, 'maslive_polyline_layer');
        _removeSourceIfExists(map, 'maslive_polyline');
        _removeSourceIfExists(map, 'maslive_polyline_segments');
        _removeLayerIfExists(map, 'maslive_polygon_line');
        _removeLayerIfExists(map, 'maslive_polygon_fill');
        _removeSourceIfExists(map, 'maslive_polygon');
      } catch (e) {
        console.error('❌ MasliveMapboxV2.clearAll error:', e);
      }
    },

    destroy: function(containerId) {
      const state = _v2State.get(containerId);
      const map = state ? state.map : null;
      if (!map) {
        _v2State.delete(containerId);
        return;
      }
      try {
        window.MasliveMapboxV2.clearAll(containerId);
        map.remove();
      } catch (e) {
        console.error('❌ MasliveMapboxV2.destroy error:', e);
      } finally {
        _v2State.delete(containerId);
      }
    },
  };

  console.log('✅ Mapbox Bridge chargé');
})();
