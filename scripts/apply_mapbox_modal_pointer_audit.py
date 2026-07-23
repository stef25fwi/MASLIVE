from __future__ import annotations

from pathlib import Path


POLAROID = Path("app/lib/ui/widgets/polaroid_poi_sheet.dart")
SELECTOR = Path("app/lib/ui/widgets/marketmap_poi_selector_sheet.dart")
POI_EDIT = Path("app/lib/admin/poi_edit_popup.dart")
CIRCUIT_EDITOR = Path("app/lib/admin/circuit_map_editor.dart")
CIRCUIT_ENTRY = Path("app/lib/admin/circuit_wizard_entry_page.dart")

POINTER_IMPORT = "import 'package:pointer_interceptor/pointer_interceptor.dart';"


def ensure_import(path: Path, anchor: str) -> None:
    source = path.read_text(encoding="utf-8")
    if POINTER_IMPORT in source:
        return
    if anchor not in source:
        raise RuntimeError(f"Import anchor missing in {path}: {anchor}")
    path.write_text(
        source.replace(anchor, f"{anchor}\n{POINTER_IMPORT}", 1),
        encoding="utf-8",
    )


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise RuntimeError(
            f"Expected exactly one {label} occurrence in {path}, found {count}"
        )
    path.write_text(source.replace(old, new, 1), encoding="utf-8")


def _matching_paren(source: str, open_index: int) -> int:
    depth = 0
    index = open_index
    quote: str | None = None
    escaped = False
    line_comment = False
    block_comment = False

    while index < len(source):
        char = source[index]
        next_char = source[index + 1] if index + 1 < len(source) else ""

        if line_comment:
            if char == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment:
            if char == "*" and next_char == "/":
                block_comment = False
                index += 2
                continue
            index += 1
            continue
        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif source.startswith(quote, index):
                index += len(quote)
                quote = None
                continue
            index += 1
            continue
        if char == "/" and next_char == "/":
            line_comment = True
            index += 2
            continue
        if char == "/" and next_char == "*":
            block_comment = True
            index += 2
            continue
        if source.startswith("'''", index) or source.startswith('\"\"\"', index):
            quote = source[index : index + 3]
            index += 3
            continue
        if char in ("'", '"'):
            quote = char
            index += 1
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1

    raise RuntimeError("Unbalanced Dart call")


def wrap_call(path: Path, marker: str, wrapper: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    marker_index = source.find(marker)
    if marker_index < 0:
        raise RuntimeError(f"Missing {label} marker in {path}: {marker}")
    call_start = marker_index + marker.rfind(" ") + 1
    open_index = source.find("(", call_start)
    if open_index < 0:
        raise RuntimeError(f"Missing opening parenthesis for {label}")
    close_index = _matching_paren(source, open_index)
    expression = source[call_start : close_index + 1]
    replacement = wrapper.replace("__CHILD__", expression)
    path.write_text(
        source[:call_start] + replacement + source[close_index + 1 :],
        encoding="utf-8",
    )


def transform_polaroid() -> None:
    print("[mapbox] polaroid POI dialog")
    ensure_import(POLAROID, "import 'package:flutter/material.dart';")
    wrap_call(
        POLAROID,
        "pageBuilder: (context, animation, secondaryAnimation) => SafeArea(",
        "PointerInterceptor(child: __CHILD__)",
        "polaroid general dialog",
    )


def transform_selector() -> None:
    print("[mapbox] MarketMap selector sheet")
    ensure_import(SELECTOR, "import 'package:flutter/material.dart';")
    wrap_call(
        SELECTOR,
        "builder: (_) => _MarketMapPoiSelectorSheet(",
        "PointerInterceptor(child: __CHILD__)",
        "MarketMap selector builder",
    )


def interaction_lock_helper() -> str:
    return """
  Future<T> _withInteractionLock<T>(Future<T> Function() action) async {
    if (mounted && !_interactionOverlayOpen) {
      setState(() => _interactionOverlayOpen = true);
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _interactionOverlayOpen = false);
      }
    }
  }
"""


def transform_poi_edit() -> None:
    print("[mapbox] POI editor and nested overlays")
    ensure_import(POI_EDIT, "import 'package:flutter/material.dart';")
    replace_once(
        POI_EDIT,
        """  bool _isSaving = false;
  bool _isUploading = false;
""",
        """  bool _isSaving = false;
  bool _isUploading = false;
  bool _interactionOverlayOpen = false;
""",
        "POI overlay lock state",
    )
    replace_once(
        POI_EDIT,
        """  double? _parseDouble(String raw) {
    final norm = raw.trim().replaceAll(',', '.');
    return double.tryParse(norm);
  }
""",
        """  double? _parseDouble(String raw) {
    final norm = raw.trim().replaceAll(',', '.');
    return double.tryParse(norm);
  }
${interaction_lock_helper()}
""",
        "POI interaction lock helper",
    )
    replace_once(
        POI_EDIT,
        """  Future<void> _onPoiMapTap(MapPoint p) async {
    final lat = p.lat;
""",
        """  Future<void> _onPoiMapTap(MapPoint p) async {
    if (_interactionOverlayOpen || _isSaving || _isUploading) return;
    final lat = p.lat;
""",
        "POI preview map guard",
    )
    wrap_call(
        POI_EDIT,
        "final shouldEdit = await showDialog<bool>(",
        "_withInteractionLock<bool?>(() => __CHILD__)",
        "POI photo edit dialog lock",
    )
    wrap_call(
        POI_EDIT,
        "builder: (ctx) => AlertDialog(",
        "PointerInterceptor(child: __CHILD__)",
        "POI photo edit dialog shield",
    )
    wrap_call(
        POI_EDIT,
        "await showModalBottomSheet<void>(",
        "_withInteractionLock<void>(() => __CHILD__)",
        "POI source picker lock",
    )
    wrap_call(
        POI_EDIT,
        "return SafeArea(",
        "PointerInterceptor(child: __CHILD__)",
        "POI source picker shield",
    )
    wrap_call(
        POI_EDIT,
        "return Theme(",
        "PointerInterceptor(child: __CHILD__)",
        "POI editor root shield",
    )


def transform_circuit_editor() -> None:
    print("[mapbox] circuit editor dialogs")
    replace_once(
        CIRCUIT_EDITOR,
        """  final bool _isEditingEnabled = true;
  int? _selectedPointIndex;
""",
        """  final bool _isEditingEnabled = true;
  bool _interactionOverlayOpen = false;
  int? _selectedPointIndex;
""",
        "circuit overlay lock state",
    )
    replace_once(
        CIRCUIT_EDITOR,
        """  void _addPoint(LngLat point) {
    setState(() {
""",
        """  void _addPoint(LngLat point) {
    if (_interactionOverlayOpen || !widget.editingEnabled) return;
    setState(() {
""",
        "circuit add point guard",
    )
    replace_once(
        CIRCUIT_EDITOR,
        """  double _toRad(double deg) => deg * math.pi / 180;
""",
        """  double _toRad(double deg) => deg * math.pi / 180;
${interaction_lock_helper()}
""",
        "circuit interaction lock helper",
    )
    wrap_call(
        CIRCUIT_EDITOR,
        "final confirm = await showDialog<bool>(",
        "_withInteractionLock<bool?>(() => __CHILD__)",
        "close-loop dialog lock",
    )
    wrap_call(
        CIRCUIT_EDITOR,
        "builder: (ctx) => AlertDialog(",
        "PointerInterceptor(child: __CHILD__)",
        "close-loop dialog shield",
    )
    wrap_call(
        CIRCUIT_EDITOR,
        "showDialog(",
        "unawaited(_withInteractionLock<void>(() async { await __CHILD__; }))",
        "clear-all dialog lock",
    )
    wrap_call(
        CIRCUIT_EDITOR,
        "builder: (ctx) => AlertDialog(",
        "PointerInterceptor(child: __CHILD__)",
        "clear-all dialog shield",
    )


def transform_circuit_entry() -> None:
    print("[mapbox] circuit wizard dialog")
    ensure_import(CIRCUIT_ENTRY, "import 'package:flutter/material.dart';")
    wrap_call(
        CIRCUIT_ENTRY,
        "return Dialog(",
        "PointerInterceptor(child: __CHILD__)",
        "new circuit dialog shield",
    )


def main() -> None:
    transform_polaroid()
    transform_selector()
    transform_poi_edit()
    transform_circuit_editor()
    transform_circuit_entry()
    print("Mapbox modal pointer audit applied successfully.")


if __name__ == "__main__":
    main()
