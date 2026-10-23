"""Build the shader distribution with Python 3.10+ (standard library only)."""
from pathlib import Path
import hashlib,re,zipfile

root=Path(__file__).resolve().parents[1]
match=re.search(r'LumenVale ([0-9]+\.[0-9]+\.[0-9]+)',(root/'pack.mcmeta').read_text(encoding='utf-8'))
if not match:raise SystemExit('Version missing from pack.mcmeta')
shader=root/'shaders'
files=sorted(p for p in shader.rglob('*') if p.is_file())
files += [root/name for name in ['pack.mcmeta','LICENSE.txt','README_UA.md','VALIDATION.json']]
for file in files:
    if not file.is_file():raise SystemExit(f'Missing file: {file.name}')
    if file.suffix not in ['.glsl','.vsh','.fsh','.csh']:continue
    for include in re.findall(r'^\s*#include\s+"([^"]+)"',file.read_text(encoding='utf-8'),re.M):
        target=shader/include.lstrip('/') if include.startswith('/') else file.parent/include
        if not target.resolve().is_relative_to(shader.resolve()) or not target.is_file():
            raise SystemExit(f'Invalid include in {file.relative_to(root)}: {include}')
dest=root/'dist';dest.mkdir(exist_ok=True)
archive=dest/f'LumenVale-{match[1]}-MC1.20.1.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as package:
    for file in sorted(files):
        info=zipfile.ZipInfo(file.relative_to(root).as_posix(),date_time=(2026,1,1,0,0,0))
        # Stable metadata across Windows development and Linux CI runners.
        info.create_system=3
        info.external_attr=0o100644 << 16
        info.compress_type=zipfile.ZIP_DEFLATED
        package.writestr(info,file.read_bytes())
with zipfile.ZipFile(archive) as package:
    if package.testzip() is not None:raise SystemExit('ZIP integrity check failed')
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(dest/'SHA256SUMS.txt').write_text(f'{digest}  {archive.name}\n',encoding='utf-8')
print(f'Built {archive.name}: {len(files)} files; SHA256 {digest}')
