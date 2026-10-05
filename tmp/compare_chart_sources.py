from pathlib import Path
import difflib
a = Path('backups/chart-modifiers-20261001/local/ChartView.luau').read_bytes().replace(b'\r\n', b'\n').decode('utf-8')
b = Path('backups/chart-modifiers-20261001/studio/ChartView.luau').read_bytes().replace(b'\r\r\n', b'\n').decode('utf-8')
print(ascii('\n'.join(difflib.unified_diff(a.splitlines(), b.splitlines()))))
