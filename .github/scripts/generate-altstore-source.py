#!/usr/bin/env python3
"""Generates altstore.json from GitHub Releases API. Reads GITHUB_TOKEN and GITHUB_REPOSITORY from env."""
import json, os, urllib.request, sys

repo = os.environ["GITHUB_REPOSITORY"]
token = os.environ["GITHUB_TOKEN"]
owner = repo.split("/")[0]

def gh_get(path):
    req = urllib.request.Request(
        f"https://api.github.com{path}",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github.v3+json"}
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

releases = gh_get(f"/repos/{repo}/releases")

versions = []
for rel in releases:
    if rel["draft"] or rel["prerelease"]:
        continue
    ipa = next((a for a in rel["assets"] if a["name"].endswith(".ipa")), None)
    if not ipa:
        continue
    versions.append({
        "version": rel["tag_name"].lstrip("v"),
        "date": rel["published_at"],
        "downloadURL": ipa["browser_download_url"],
        "size": ipa["size"],
        "versionDescription": rel["body"] or "",
    })

if not versions:
    print("No IPA releases found", file=sys.stderr)
    sys.exit(1)

latest = versions[0]

source = {
    "name": "Nearby Glasses",
    "subtitle": "Detect smart glasses nearby via BLE",
    "description": "Scans Bluetooth Low Energy advertisements to detect smart glasses devices.",
    "iconURL": f"https://raw.githubusercontent.com/{repo}/main/img/icon.png",
    "website": f"https://github.com/{repo}",
    "sourceURL": f"https://{owner}.github.io/{repo.split('/')[1]}/altstore.json",
    "apps": [{
        "name": "Nearby Glasses",
        "bundleIdentifier": "com.nearbyglasses.app",
        "developerName": "NearbyGlasses Contributors",
        "localizedDescription": "Scans Bluetooth Low Energy advertisements to detect smart glasses devices nearby. No account required.",
        "iconURL": f"https://raw.githubusercontent.com/{repo}/main/img/icon.png",
        "downloadURL": latest["downloadURL"],
        "version": latest["version"],
        "versionDescription": latest["versionDescription"],
        "size": latest["size"],
        "appPermissions": {
            "entitlements": [],
            "privacy": [{
                "name": "Bluetooth",
                "usageDescription": "Nearby Glasses scans Bluetooth Low Energy advertisements to detect smart glasses devices nearby."
            }]
        },
        "versions": versions,
    }],
    "news": [],
}

print(json.dumps(source, indent=2))
