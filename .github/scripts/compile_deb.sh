#!/bin/env bash

if [ -z $GITHUB_WORKSPACE ]; then
    echo "This script should only run on GitHub action!" >&2
    exit 1
fi

cd $GITHUB_WORKSPACE

out="$GITHUB_WORKSPACE/out"
termux_prefix="/data/data/com.termux/files/usr"
version="$(cat version)"
version_code="$(git rev-list HEAD --count)"
release_code="$(git rev-list HEAD --count)-$(git rev-parse --short HEAD)-release"
deb_name="oneshot-$version-$release_code.deb"

echo "=== Starting build ==="
echo "Version: $version"
echo "Version code: $version_code"
echo "Release code: $release_code"
echo "Deb name: $deb_name"
echo "Output directory: $out"

# Bersihkan dan buat struktur folder
rm -rf "$out"
mkdir -v "$out"
mkdir -v "$out/deb"
mkdir -pv "$out/deb$termux_prefix/bin"
mkdir -pv "$out/deb$termux_prefix/share/oneshot"
mkdir -pv "$out/deb/DEBIAN"

# === 1. Salin binary utama ===
if [ -f "src/oneshot" ]; then
    cp -v src/oneshot "$out/deb$termux_prefix/bin/"
    chmod +x "$out/deb$termux_prefix/bin/oneshot"
else
    echo "❌ src/oneshot tidak ditemukan!"
    exit 1
fi

# === 2. Salin semua file pendukung dari deb/ (kecuali dpkg-conf) ===
for file in deb/*; do
    if [ -f "$file" ] && [ "$(basename "$file")" != "dpkg-conf" ]; then
        cp -v "$file" "$out/deb$termux_prefix/share/oneshot/"
    fi
done

# === 3. Salin file kontrol dpkg-conf ke DEBIAN/control ===
if [ -f "deb/dpkg-conf" ]; then
    cp -v deb/dpkg-conf "$out/deb/DEBIAN/control"
else
    echo "❌ deb/dpkg-conf tidak ditemukan!"
    exit 1
fi

# === 4. Set permission ===
chmod -Rv 755 "$out/deb/DEBIAN"
chmod -Rv 755 "$out/deb$termux_prefix/bin"

# === 5. Update versi di control ===
sed -i "s/^Version: .*/Version: $version.$version_code/" "$out/deb/DEBIAN/control"

# === 6. Build package ===
cd "$out/deb"
echo "Building .deb package..."
dpkg -b . "$GITHUB_WORKSPACE/$deb_name"

# === 7. Verifikasi ===
if [ -f "$GITHUB_WORKSPACE/$deb_name" ]; then
    echo "✅ .deb file created successfully: $GITHUB_WORKSPACE/$deb_name"
    echo "deb_out=$GITHUB_WORKSPACE/$deb_name" >> $GITHUB_OUTPUT
else
    echo "❌ Failed to create .deb file!"
    exit 1
fi
