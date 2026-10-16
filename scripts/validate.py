#!/usr/bin/env python3
"""Check repository consistency without pretending this replaces an iOS build."""
from pathlib import Path
import json
import plistlib
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
failures = []
def check(condition, message):
    if not condition:
        failures.append(message)
def command(args):
    result = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
    check(result.returncode == 0, ' '.join(args) + '\n' + result.stdout + result.stderr)

required = ['Config/Project.xcconfig','Config/Signing.local.xcconfig.example','Package.swift','ADeux.xcodeproj/project.pbxproj','README.md','AGENTS.md','CLAUDE.md','agent.md','docs/architecture.md','docs/apple-setup.md','Makefile','.github/workflows/ci.yml','scripts/swift-test.sh','scripts/swift-build.sh','scripts/ios-build.sh','scripts/render-preview.sh']
for path in required:
    check((ROOT / path).is_file(), 'Missing ' + path)
for name in ['developing-swiftui','cloudkit-sharing','validating-adeux']:
    path = ROOT / '.agents/skills' / name / 'SKILL.md'
    check(path.is_file(), 'Missing skill ' + name)
    if path.is_file():
        content = path.read_text()
        check(content.startswith('---\n') and f'name: {name}\n' in content and '\ndescription: ' in content, 'Invalid skill frontmatter: ' + name)
        check(not re.search(r'\b(TODO|TBD|PLACEHOLDER)\b', content), 'Unfinished skill: ' + name)
check((ROOT / '.claude/skills').is_symlink(), 'Claude skills should link to canonical .agents skills')
check((ROOT / '.claude/skills').resolve() == (ROOT / '.agents/skills').resolve(), 'Claude skills symlink target mismatch')
for path in (ROOT / 'App').glob('*.plist'):
    try:
        plistlib.loads(path.read_bytes())
    except Exception as error:
        failures.append(f'{path}: {error}')
for path in (ROOT / 'App').glob('*.entitlements'):
    try:
        plistlib.loads(path.read_bytes())
    except Exception as error:
        failures.append(f'{path}: {error}')
for path in (ROOT / 'App/Assets.xcassets').rglob('Contents.json'):
    try:
        data = json.loads(path.read_text())
        for image in data.get('images', []):
            check((path.parent / image.get('filename','')).is_file(), 'Missing catalog image in ' + str(path))
    except Exception as error:
        failures.append(f'{path}: {error}')
for path in (ROOT / 'ADeux.xcodeproj/xcshareddata/xcschemes').glob('*.xcscheme'):
    try:
        ET.parse(path)
    except Exception as error:
        failures.append(f'{path}: {error}')
project = ROOT / 'ADeux.xcodeproj/project.pbxproj'
if project.exists():
    with tempfile.TemporaryDirectory(prefix='adeux-project-check-') as temporary:
        command([sys.executable, 'scripts/generate_project.py', '--output-dir', temporary])
        generated = Path(temporary) / 'ADeux.xcodeproj'
        for expected in generated.rglob('*'):
            if expected.is_file():
                actual = ROOT / 'ADeux.xcodeproj' / expected.relative_to(generated)
                check(actual.is_file() and actual.read_bytes() == expected.read_bytes(), 'Generated project differs: ' + str(actual.relative_to(ROOT)) + '. Use Config/Signing.local.xcconfig for signing, or run make project after updating the generator.')
    command(['plutil','-lint',str(project)])
    result = subprocess.run(['plutil','-convert','json','-o','-',str(project)],text=True,capture_output=True)
    if result.returncode == 0:
        objects = json.loads(result.stdout)['objects']
        for obj in objects.values():
            if obj.get('isa') == 'PBXFileReference' and obj.get('sourceTree') == '<group>' and obj.get('path','').endswith('.swift') and obj.get('path') != 'Package.swift':
                check((ROOT/'App'/obj['path']).is_file(), 'Xcode source missing: ' + obj['path'])
    else:
        failures.append('Cannot parse Xcode project: ' + result.stderr)
command(['swiftc','-frontend','-parse'] + [str(path) for path in sorted((ROOT/'App').glob('*.swift'))])
for path in (ROOT/'scripts').glob('*.sh'):
    command(['bash','-n',str(path)])
for path in (ROOT/'scripts').glob('*.py'):
    try:
        compile(path.read_text(), str(path), 'exec')
    except SyntaxError as error:
        failures.append(str(error))
if failures:
    print('\n\n'.join(failures),file=sys.stderr)
    sys.exit(1)
print('Repository, skills, Xcode project, assets, iOS syntax and shell/Python syntax checks passed.')
print('This does not compile the iOS target or test iCloud on devices.')
