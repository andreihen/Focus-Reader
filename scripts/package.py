"""Build the manual-install ZIP without settings, caches or runtime dependencies."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED
import hashlib
import os
import subprocess

root = Path(__file__).resolve().parents[1]
source = root / 'focusreader.koplugin'
out = root / 'dist'
out.mkdir(exist_ok=True)
archive = out / 'focusreader-0.1.0.zip'
files = {p.relative_to(source).as_posix(): p.read_bytes()
         for p in source.rglob('*')
         if p.is_file() and (p.suffix in {'.lua', '.md'} or p.name == 'LICENSE')}
manual = (root/'README.md').read_text().replace('focusreader.koplugin/THIRD_PARTY.md','THIRD_PARTY.md')
files['MANUAL.md'] = manual.encode()
for doc in (root/'docs').glob('*.md'):
    files['docs/'+doc.name] = doc.read_bytes()
# Parse/compile every shipped Lua file, without executing it.
luajit = Path(os.environ.get('FOCUS_TOOLS_DIR','/workspace/.focus-reader-tools-2026.07.1'))/'lib/koreader/luajit'
if not luajit.is_file():
    raise SystemExit('LuaJIT validation runtime missing. Run make setup first.')
for script in source.rglob('*.lua'):
    subprocess.run([str(luajit), '-b', str(script), os.devnull],cwd=luajit.parent,check=True)
with ZipFile(archive,'w') as z:
    for name,data in sorted(files.items()):
        info = ZipInfo('focusreader.koplugin/'+name, date_time=(2026,1,1,0,0,0))
        info.compress_type = ZIP_DEFLATED
        info.external_attr = 0o100644 << 16
        z.writestr(info,data)
with ZipFile(archive) as z:
    assert z.testzip() is None
    assert all(n.startswith('focusreader.koplugin/') and '..' not in n.split('/') for n in z.namelist())
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(out/(archive.name+'.sha256')).write_text(digest+'  '+archive.name+'\n')
manifest = '\n'.join(f'{hashlib.sha256(data).hexdigest()}  focusreader.koplugin/{name}' for name,data in sorted(files.items()))+'\n'
(out/'MANIFEST.sha256').write_text(manifest)
print(f'{archive}: {len(files)} files, {archive.stat().st_size} bytes')
print('SHA-256 '+digest)
