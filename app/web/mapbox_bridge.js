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
    markers: new Map(),
    sources: new Map(),
    layers: new Map(),
    userMarker: null,
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
      window.MapboxBridge.map = map;

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

        // Callback vers Flutter si disponible
        if (window.onMapboxReady) {
          window.onMapboxReady();
        }
      });

      map.on('error', function(e) {
        console.error('❌ Mapbox error:', e);
      });

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

  const _v2State = new Map(); // containerId -> { map, markers: Map<string, Marker> }

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
    const state = { map, markers: new Map() };
    _v2State.set(containerId, state);
    return state;
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

  window.MasliveMapboxV2 = {
    init: function(containerId, token, optionsJson) {
      try {
        const options = optionsJson ? JSON.parse(optionsJson) : {};
        const map = window.initMapboxMap(containerId, token, options);
        if (!map) return false;

        const state = _ensureState(containerId, map);
        state.map = map;

        map.on('load', function() {
          _postToFlutter({ type: 'MASLIVE_MAP_READY', containerId });
        });

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

          const marker = new mapboxgl.Marker({ element: el })
            .setLngLat([Number(m.lng), Number(m.lat)])
            .addTo(map);
          state.markers.set(String(m.id || ''), marker);
        }
      } catch (e) {
        console.error('❌ MasliveMapboxV2.setMarkers error:', e);
      }
    },

    setPolyline: function(containerId, pointsJson, colorHex, width, show) {
      const map = _getMap(containerId);
      if (!map) return;
      const sourceId = 'maslive_polyline';
      const layerId = 'maslive_polyline_layer';

      try {
        if (!show) {
          _removeLayerIfExists(map, layerId);
          _removeSourceIfExists(map, sourceId);
          return;
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
          map.addLayer({
            id: layerId,
            type: 'line',
            source: sourceId,
            paint: {
              'line-width': Number(width || 3),
              'line-color': String(colorHex || '#FF0000'),
            },
          });
        } else {
          src.setData(geojson);
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
        // markers
        state.markers.forEach((marker) => {
          try { marker.remove(); } catch (_) {}
        });
        state.markers.clear();

        // layers/sources
        _removeLayerIfExists(map, 'maslive_polyline_layer');
        _removeSourceIfExists(map, 'maslive_polyline');
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
