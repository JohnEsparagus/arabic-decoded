#!/usr/bin/env python3
"""Refreshes assets/data/manifest.json after content changes.

Records a hash of every content file, and bumps the manifest's version if
any of them changed. Pushing to main then publishes the content, and apps
pick it up on their next launch after that. Run from the project root:

    python3 tool/build_manifest.py
"""
import glob
import hashlib
import json
import os

DATA = 'assets/data'
MANIFEST = f'{DATA}/manifest.json'
# Not content: the manifest itself, the update log (shipped with each app
# version) and an old fixture only the tests use.
SKIP = {'manifest.json', 'dev_updates.json', 'campaign.json'}


def file_hash(path):
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()[:16]


with open(MANIFEST, encoding='utf-8') as f:
    manifest = json.load(f)

files = {
    path: file_hash(path)
    for path in sorted(glob.glob(f'{DATA}/*.json'))
    if os.path.basename(path) not in SKIP
}
for campaign in manifest['campaigns']:
    if campaign['file'] not in files:
        raise SystemExit(f"Campaign file missing: {campaign['file']}")

if files != manifest.get('files'):
    manifest['version'] = manifest.get('version', 0) + 1
    manifest['files'] = files
    print(f"Content changed: now version {manifest['version']}")
else:
    print(f"No content changes: still version {manifest['version']}")

with open(MANIFEST, 'w', encoding='utf-8') as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write('\n')
