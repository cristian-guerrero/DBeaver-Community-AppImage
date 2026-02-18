#!/bin/bash
set -e

# 1. Fetch latest DBeaver release info
RELEASES_URL="https://api.github.com/repos/dbeaver/dbeaver/releases/latest"
DOWNLOAD_URL=$(curl -s "$RELEASES_URL" | jq -r '.assets[] | select(.name | test("linux-x86_64.tar.gz$")) | .browser_download_url')
VERSION=$(curl -s "$RELEASES_URL" | jq -r '.tag_name')

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" == "null" ]; then
  echo "Error: Could not find download URL for DBeaver."
  exit 1
fi
echo "Download URL: $DOWNLOAD_URL"
echo "Version: $VERSION"

# 2. Download and extract
mkdir -p build
cd build
wget -q --show-progress "$DOWNLOAD_URL" -O dbeaver.tar.gz
mkdir -p DBeaver.AppDir
tar -xzf dbeaver.tar.gz -C DBeaver.AppDir --strip-components=1

# 3. Create AppRun
cat <<EOF > DBeaver.AppDir/AppRun
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\${0}")")"
# DBeaver usually includes its own JRE or uses system one. 
# We'll point to its internal one if available.
if [ -d "\${HERE}/jre" ]; then
    export JAVA_HOME="\${HERE}/jre"
    export PATH="\${JAVA_HOME}/bin:\${PATH}"
fi
exec "\${HERE}/dbeaver" "\$@"
EOF
chmod +x DBeaver.AppDir/AppRun

# 4. Create Desktop File
cat <<EOF > DBeaver.AppDir/dbeaver.desktop
[Desktop Entry]
Name=DBeaver Community
Exec=dbeaver %U
Terminal=false
Type=Application
Icon=dbeaver
Categories=Development;Database;
Comment=Free universal database tool and SQL client
StartupWMClass=DBeaver
EOF

# 5. Copy Icon
# DBeaver usually has icons in the root or icons folder
cp DBeaver.AppDir/icon.xpm DBeaver.AppDir/dbeaver.xpm || true
cp DBeaver.AppDir/dbeaver.png DBeaver.AppDir/dbeaver.png || \
find DBeaver.AppDir -name "icon.png" -exec cp {} DBeaver.AppDir/dbeaver.png \; -quit || true

# 6. Download appimagetool
wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool
chmod +x appimagetool

# 7. Build AppImage
export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1

REPO_OWNER=$(echo $GITHUB_REPOSITORY | cut -d'/' -f1)
REPO_NAME=$(echo $GITHUB_REPOSITORY | cut -d'/' -f2)

if [ ! -z "$GITHUB_REPOSITORY" ]; then
  UPDATE_INFO="gh-releases-zsync|${REPO_OWNER}|${REPO_NAME}|latest|DBeaver-Community-x86_64.AppImage.zsync"
  ./appimagetool -u "$UPDATE_INFO" DBeaver.AppDir DBeaver-Community-x86_64.AppImage
else
  ./appimagetool DBeaver.AppDir DBeaver-Community-x86_64.AppImage
fi

echo "Build complete: build/DBeaver-Community-x86_64.AppImage"
