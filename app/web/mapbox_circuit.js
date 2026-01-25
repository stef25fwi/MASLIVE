window.masliveMapbox = (() => {
  let map;
  const srcMask = "maslive_mask";
  const srcPerimeter = "maslive_perimeter";
  const srcRoute = "maslive_route";
  const srcSegments = "maslive_segments";

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
    mapboxgl.accessToken = token;
    map = new mapboxgl.Map({
      container: containerId,
      style: "mapbox://styles/mapbox/streets-v12",
      center: centerLngLat,
      zoom: zoom ?? 12
    });

    map.on("load", () => {
      ensureSourcesAndLayers();
      map.on("click", (e) => {
        window.postMessage({ type: "MASLIVE_MAP_TAP", lng: e.lngLat.lng, lat: e.lngLat.lat }, "*");
      });
    });
  }

  function setData({ perimeter, mask, route, segments }) {
    if (!map) return;
    ensureSourcesAndLayers();
    if (perimeter) map.getSource(srcPerimeter).setData(perimeter);
    if (mask) map.getSource(srcMask).setData(mask);
    if (route) map.getSource(srcRoute).setData(route);
    if (segments) map.getSource(srcSegments).setData(segments);
  }

  function fc(features) { return { type: "FeatureCollection", features }; }

  return { init, setData };
})();
