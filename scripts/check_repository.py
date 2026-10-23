"""Validate documentation links and the installable release distribution."""
from pathlib import Path
import hashlib
import json
import re
import zipfile
from urllib.parse import unquote, urlsplit

root = Path(__file__).resolve().parents[1]
ignored = {'.git', '.validation', 'dist', 'downloads', '__pycache__'}
link_count = 0
for document in sorted(root.rglob('*.md')):
    if any(part in ignored for part in document.relative_to(root).parts):
        continue
    for match in re.finditer(r'!?\[[^\]]*\]\((?:<([^>]+)>|([^\s)]+))(?:\s+[^)]*)?\)', document.read_text(encoding='utf-8')):
        target = match[1] or match[2]
        parsed = urlsplit(target)
        if parsed.scheme or parsed.netloc or not parsed.path:
            continue
        resolved = (document.parent / unquote(parsed.path)).resolve()
        if not resolved.is_relative_to(root) or not resolved.exists():
            raise SystemExit(f'Broken local link in {document.relative_to(root)}: {target}')
        link_count += 1

version = re.search(r'LumenVale (\d+\.\d+\.\d+)', (root / 'pack.mcmeta').read_text(encoding='utf-8'))[1]
filename = f'LumenVale-{version}-MC1.20.1.zip'
checksums = {}
for line in (root / 'downloads/SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():
    if not line.strip():
        continue
    digest, name = line.split()
    if not re.fullmatch(r'[0-9a-f]{64}', digest) or Path(name).name != name or name in checksums:
        raise SystemExit(f'Invalid checksum entry: {line}')
    archive = root / 'downloads' / name
    if not archive.is_file() or hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
        raise SystemExit(f'Checksum mismatch: {name}')
    checksums[name] = digest
if filename not in checksums:
    raise SystemExit(f'Current release missing from checksums: {filename}')

with zipfile.ZipFile(root / 'downloads' / filename) as archive:
    if archive.testzip() is not None:
        raise SystemExit('Invalid release ZIP')
    names = archive.namelist()
    if len(names) != len(set(names)) or 'shaders/shaders.properties' not in names:
        raise SystemExit('Release ZIP has invalid structure')
    for name in names:
        source = (root / name).resolve()
        if not source.is_relative_to(root) or not source.is_file() or archive.read(name) != source.read_bytes():
            raise SystemExit(f'Release ZIP differs from sources: {name}')
    bundled_report = json.loads(archive.read('VALIDATION.json'))
    if bundled_report['version'] != version:
        raise SystemExit('Validation report version differs from release')

built = root / 'dist' / filename
if not built.is_file() or hashlib.sha256(built.read_bytes()).hexdigest() != checksums[filename]:
    raise SystemExit('Run scripts/build.py; the build must match the published distribution')
source_hash = hashlib.sha256()
for source in sorted((root / 'shaders').rglob('*')):
    if source.is_file():
        source_hash.update(source.relative_to(root / 'shaders').as_posix().encode() + b'\0' + source.read_bytes())
if source_hash.hexdigest() != bundled_report['shader_tree_sha256']:
    raise SystemExit('Validation report does not match current shader sources')
print(f'Passed: {link_count} local documentation links, {len(checksums)} release checksums, ZIP/source parity and shader tree hash.')
