window.masliveMapbox = (() => {
  let map;
  const srcMask = "maslive_mask";
  const srcPerimeter = "maslive_perimeter";
  const srcRoute = "maslive_route";
  const srcSegments = "maslive_segments";

  // Attendre que mapboxgl soit disponible
  function waitForMapboxGL() {
    return new Promise((resolve) => {
      if (typeof mapboxgl !== 'undefined') {
        resolve();
        return;
      }
      const checkInterval = setInterval(() => {
        if (typeof mapboxgl !== 'undefined') {
          clearInterval(checkInterval);
          resolve();
        }
      }, 100);
      // Timeout après 10 secondes
      setTimeout(() => {
        clearInterval(checkInterval);
        resolve();
      }, 10000);
    });
  }

  function ensureSourcesAndLayers() {
    if (!map.getSource(srcMask)) map.addSource(srcMask, { type: "geojson", data: fc([]) });
    if (!map.getSource(srcPerimeter)) map.addSource(srcPerimeter, { type: "geojson", data: fc([]) });
    if (!map.getSource(srcRoute)) map.addSource(srcRoute, { type: "geojson", data: fc([]) });
    if (!map.getSource(srcSegments)) map.addSource(srcSegments, { type: "geojson", data: fc([]) });

    if (!map.getLayer("mask")) {
      map.addLayer({ id: "mask", type: "fill", source: srcMask, paint: { "fill-opacity": 0.35 } });
    }
    if (!map.getLayer("perimeter")) {
      map.addLayer({
        id: "perimeter",
        type: "line",
        source: srcPerimeter,
        paint: { "line-width": 3 }
      });
    }
    if (!map.getLayer("route")) {
      map.addLayer({
        id: "route",
        type: "line",
        source: srcRoute,
        paint: { "line-width": 6 }
      });
    }
    if (!map.getLayer("segments")) {
      map.addLayer({
        id: "segments",
        type: "line",
        source: srcSegments,
        paint: {
          "line-width": ["coalesce", ["get", "width"], 8],
          "line-color": ["coalesce", ["get", "color"], "#00AEEF"]
        }
      });
    }

    // Flèches: symbol sur ligne (nécessite une image dans le style)
    if (!map.hasImage("arrow")) {
      // Flèche simple en data URI (tu peux remplacer par loadImage)
      const canvas = document.createElement("canvas");
      canvas.width = 64; canvas.height = 64;
      const ctx = canvas.getContext("2d");
      ctx.fillStyle = "white";
      ctx.beginPath();
      ctx.moveTo(16, 32); ctx.lineTo(48, 16); ctx.lineTo(48, 48); ctx.closePath();
      ctx.fill();
      map.addImage("arrow", ctx.getImageData(0,0,64,64), { sdf:false });
    }
    if (!map.getLayer("arrows")) {
      map.addLayer({
        id: "arrows",
        type: "symbol",
        source: srcRoute,
        layout: {
          "symbol-placement": "line",
          "symbol-spacing": 120,
          "icon-image": "arrow",
          "icon-size": 0.35,
          "icon-allow-overlap": true,
          "icon-rotation-alignment": "map"
        }
      });
    }
  }

  function init(containerId, token, centerLngLat, zoom) {
    // Vérifier que mapboxgl est disponible
    if (typeof mapboxgl === 'undefined') {
      console.error('❌ mapboxgl is not available. Make sure mapbox-gl.js is loaded in index.html');
      return false;
    }
    
    if (!token || token.length === 0) {
      console.error('❌ Token Mapbox vide');
      return false;
    }
    
    try {
      mapboxgl.accessToken = token;
      console.log('🔑 Token: ' + token.substring(0, 10) + '...');
      
      map = new mapboxgl.Map({
        container: containerId,
        style: "mapbox://styles/mapbox/streets-v12",
        center: centerLngLat,
        zoom: zoom ?? 12
      });
      console.log('🗺️ Map created');

      // Resize instantané sur changement de taille du conteneur (rotation
      // portrait/paysage, panneaux wizard qui s'ouvrent/ferment). rAF-throttlé.
      try {
        const el = document.getElementById(containerId);
        if (typeof ResizeObserver !== 'undefined' && el) {
          let rafId = 0;
          let lastW = 0;
          let lastH = 0;
          const ro = new ResizeObserver((entries) => {
            let w = 0;
            let h = 0;
            try {
              const rect = entries && entries[0] ? entries[0].contentRect : null;
              if (rect) { w = Math.round(rect.width); h = Math.round(rect.height); }
            } catch (_) { /* ignore */ }
            if (w === lastW && h === lastH) return;
            lastW = w;
            lastH = h;
            if (rafId) return;
            rafId = requestAnimationFrame(() => {
              rafId = 0;
              try { if (map) map.resize(); } catch (_) { /* ignore */ }
            });
          });
          ro.observe(el);
          map.on('remove', () => {
            try { if (rafId) cancelAnimationFrame(rafId); } catch (_) {}
            try { ro.disconnect(); } catch (_) {}
          });
        }
      } catch (_) {
        // ResizeObserver best-effort.
      }

      map.on("load", () => {
        console.log('✅ Mapbox loaded');
        ensureSourcesAndLayers();
        map.on("click", (e) => {
          window.postMessage({ type: "MASLIVE_MAP_TAP", lng: e.lngLat.lng, lat: e.lngLat.lat, containerId: containerId }, "*");
        });
      });
      
      map.on("error", (e) => {
        console.error('❌ Mapbox error:', e.error);
      });
      
      return true;
    } catch (e) {
      console.error('❌ Init error:', e);
      return false;
    }
  }

  function setData({ perimeter, mask, route, segments }) {
    if (!map) {
      console.error('❌ Carte non initialisée');
      return false;
    }
    
    try {
      ensureSourcesAndLayers();
      
      // Vérifier et mettre à jour chaque source
      const updateSource = (srcName, data, label) => {
        const source = map.getSource(srcName);
        if (!source) {
          console.warn('⚠️  Source ' + srcName + ' non trouvée');
          return false;
        }
        try {
          source.setData(data);
          console.log('✅ ' + label + ' mis à jour');
          return true;
        } catch (e) {
          console.error('❌ Erreur ' + label + ':', e);
          return false;
        }
      };
      
      if (perimeter) {
        updateSource(srcPerimeter, perimeter, 'Périmètre');

        // Calculer des bounds approximatifs sur le périmètre et
        // limiter le déplacement de la carte à cette zone.
        try {
          const bounds = computeBoundsFromFc(perimeter);
          if (bounds) {
            map.setMaxBounds(bounds);
          }
        } catch (e) {
          console.warn('⚠️ Erreur computeBoundsFromFc:', e);
        }
      }
      if (mask) updateSource(srcMask, mask, 'Masque');
      if (route) updateSource(srcRoute, route, 'Route');
      if (segments) updateSource(srcSegments, segments, 'Segments');
      
      console.log('✅ Toutes les données mises à jour');
      return true;
    } catch (e) {
      console.error('❌ Erreur setData:', e);
      return false;
    }
  }

  function fc(features) { return { type: "FeatureCollection", features }; }

  // Calcule [[minLng, minLat], [maxLng, maxLat]] à partir
  // d'un FeatureCollection (LineString) pour le périmètre.
  function computeBoundsFromFc(featureCollection) {
    if (!featureCollection || !Array.isArray(featureCollection.features) || featureCollection.features.length === 0) {
      return null;
    }

    let minLng = Infinity;
    let minLat = Infinity;
    let maxLng = -Infinity;
    let maxLat = -Infinity;

    for (const feat of featureCollection.features) {
      if (!feat || !feat.geometry) continue;
      const geom = feat.geometry;
      const type = geom.type;
      const coords = geom.coordinates;
      if (!coords) continue;

      const visitPoint = (lng, lat) => {
        if (typeof lng !== 'number' || typeof lat !== 'number') return;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
      };

      if (type === 'LineString') {
        for (const p of coords) {
          if (!Array.isArray(p) || p.length < 2) continue;
          visitPoint(p[0], p[1]);
        }
      } else if (type === 'MultiLineString') {
        for (const line of coords) {
          if (!Array.isArray(line)) continue;
          for (const p of line) {
            if (!Array.isArray(p) || p.length < 2) continue;
            visitPoint(p[0], p[1]);
          }
        }
      }
    }

    if (!isFinite(minLng) || !isFinite(minLat) || !isFinite(maxLng) || !isFinite(maxLat)) {
      return null;
    }

    return [
      [minLng, minLat],
      [maxLng, maxLat]
    ];
  }

  return { init, setData };
})();
