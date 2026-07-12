from pathlib import Path

path = Path(__file__).with_name('apply_group_tracking_consistency_patch.py')
value = path.read_text(encoding='utf-8')
marker = '    "tracker mounted guard",\n)\n'
marker_index = value.index(marker)
start = value.rfind('value = replace_once(\n', 0, marker_index)
end = marker_index + len(marker)
replacement = '''load_start = value.index("  Future<void> _loadTrackerProfile() async {")
load_end = value.index("  Future<void> _scanQr() async {", load_start)
load_block = value[load_start:load_end]
old_loading = "      setState(() => _isLoading = false);"
if old_loading not in load_block:
    raise RuntimeError("tracker mounted guard: loading statement not found")
load_block = load_block.replace(
    old_loading,
    "      if (mounted) setState(() => _isLoading = false);",
    1,
)
value = value[:load_start] + load_block + value[load_end:]
'''
path.write_text(value[:start] + replacement + value[end:], encoding='utf-8')
print('Tracker patch assertion fixed.')
