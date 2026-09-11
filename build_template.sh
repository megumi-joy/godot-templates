#!/bin/bash
# Build a size-trimmed Godot Android export template (arm64 only).
# Usage: build_template.sh <godot-tag> <ndk-version> <vulkan yes|no>
set -euo pipefail
TAG=$1; NDK=$2; VULKAN=$3
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq git scons python3 gcc g++ pkg-config openjdk-17-jdk-headless unzip curl ca-certificates > /dev/null
export ANDROID_HOME=/w/sdk JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
mkdir -p $ANDROID_HOME/cmdline-tools
if [ ! -d $ANDROID_HOME/cmdline-tools/latest ]; then
  curl -sSL -o /tmp/ct.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q /tmp/ct.zip -d /tmp/ct && mv /tmp/ct/cmdline-tools $ANDROID_HOME/cmdline-tools/latest
fi
SDKM=$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager
yes | $SDKM --licenses > /dev/null 2>&1 || true
$SDKM "platform-tools" "build-tools;34.0.0" "platforms;android-34" "cmake;3.22.1" "ndk;$NDK" > /dev/null
export ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/$NDK
SRC=/w/godot-$TAG
[ -d $SRC ] || git clone -q --depth 1 --branch $TAG https://github.com/godotengine/godot.git $SRC
cd $SRC
# 4.5+ refuses to build without Swappy frame pacing (script downloads the prebuilt lib).
[ -f misc/scripts/install_swappy_android.py ] && python3 misc/scripts/install_swappy_android.py 2>&1 | tail -2
OPTS="platform=android target=template_release arch=arm64 production=yes optimize=size lto=thin deprecated=no \
  vulkan=$VULKAN opengl3=yes \
  module_mono_enabled=no module_openxr_enabled=no module_webxr_enabled=no module_mobile_vr_enabled=no \
  module_csg_enabled=no module_gridmap_enabled=no module_navigation_enabled=no module_msdfgen_enabled=no \
  module_raycast_enabled=no module_camera_enabled=no module_lightmapper_rd_enabled=no module_denoise_enabled=no \
  module_text_server_adv_enabled=no module_text_server_fb_enabled=yes \
  module_fbx_enabled=no module_gltf_enabled=no module_ktx_enabled=no module_basis_universal_enabled=no \
  module_tga_enabled=no module_tinyexr_enabled=no module_hdr_enabled=no module_bmp_enabled=no module_svg_enabled=no \
  module_cvtt_enabled=no module_etcpak_enabled=no module_astcenc_enabled=no module_squish_enabled=no \
  module_xatlas_unwrap_enabled=no module_vhacd_enabled=no module_upnp_enabled=no module_jsonrpc_enabled=no \
  module_interactive_music_enabled=no module_zip_enabled=no module_theora_enabled=no module_dds_enabled=no \
  module_betsy_enabled=no"
echo "=== scons $TAG ($(nproc) jobs) ==="; date
scons -j$(nproc) $OPTS 2>&1 | tail -20
ls -la bin/
cd platform/android/java
./gradlew --no-daemon -q generateGodotTemplates 2>&1 | tail -10
cd $SRC
ls -la bin/android_*
mkdir -p /w/out/$TAG && cp bin/android_release.apk bin/android_source.zip /w/out/$TAG/
unzip -l bin/android_release.apk | grep -E 'libgodot|total'
echo "=== done $TAG ==="; date
