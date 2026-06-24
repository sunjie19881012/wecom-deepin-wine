#!/bin/bash
#
# 重新构建补丁包（用于更新或自定义）
# 用法: bash build-patch-packages.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/packages"
mkdir -p "$PACKAGES_DIR"

echo "=== 构建 dummy-libsane 补丁包 ==="
mkdir -p /tmp/dummy-libsane/DEBIAN
cat > /tmp/dummy-libsane/DEBIAN/control << "CONTROL"
Package: dummy-libsane
Version: 1.0
Architecture: all
Maintainer: wecom-installer
Description: Dummy package to provide libsane for deepin-wine
 Ubuntu's libsane1 does not declare Provides: libsane,
 which deepin-wine10-stable depends on.
Provides: libsane (= 1.0.24)
CONTROL
dpkg-deb --root-owner-group -b /tmp/dummy-libsane "$PACKAGES_DIR/dummy-libsane_1.0_all.deb"
rm -rf /tmp/dummy-libsane

echo ""
echo "=== 下载并重新打包 deepin-wine10-stable ==="
cd /tmp
if [ ! -f deepin-wine10-stable_*.deb ]; then
    echo "下载 deepin-wine10-stable..."
    apt-get download deepin-wine10-stable
fi

WINE_DEB=$(ls deepin-wine10-stable_*.deb | head -1)
rm -rf wine-repack
mkdir -p wine-repack/extracted
dpkg-deb -R "$WINE_DEB" wine-repack/extracted

# 移除 Ubuntu 上无法满足的依赖：libsane（由补丁包提供）、
# libcapi20-3、libasound2-plugins（实际运行时无需）、
# deepin-elf-verify（依赖缺失的 libssl1.1，运行时不用）
sed -i \
    -e 's/, libcapi20-3,/,/g' \
    -e 's/, libsane (>= 1.0.24),/,/g' \
    -e 's/, libasound2-plugins,/,/g' \
    -e 's/, deepin-elf-verify (>= 1.1.10-1)//g' \
    wine-repack/extracted/DEBIAN/control

# 调整版本号
sed -i 's/^Version: 10.14deepin8/Version: 10.14deepin8patched1/' wine-repack/extracted/DEBIAN/control

dpkg-deb --root-owner-group -b wine-repack/extracted "$PACKAGES_DIR/deepin-wine10-stable-patched.deb"
rm -rf wine-repack

echo ""
echo "=== 下载并重新打包 deepin-wine-helper ==="
if [ ! -f deepin-wine-helper_*.deb ]; then
    echo "下载 deepin-wine-helper..."
    apt-get download deepin-wine-helper
fi

HELPER_DEB=$(ls deepin-wine-helper_*.deb | head -1)
rm -rf helper-repack
mkdir -p helper-repack/extracted
dpkg-deb -R "$HELPER_DEB" helper-repack/extracted

# helper 依赖 deepin-elf-verify，但实际运行不需要
sed -i -e 's/, deepin-elf-verify (>= 1.1.10-1)//g' \
    helper-repack/extracted/DEBIAN/control

dpkg-deb --root-owner-group -b helper-repack/extracted "$PACKAGES_DIR/deepin-wine-helper-patched.deb"
rm -rf helper-repack

echo ""
echo "=== 完成 ==="
echo "补丁包已保存到: $PACKAGES_DIR/"
ls -lh "$PACKAGES_DIR/"
