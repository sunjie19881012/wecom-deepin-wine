#!/bin/bash
#
# Ubuntu 26.04 企业微信安装脚本（Deepin Wine 版）
# 用法: sudo bash install.sh
#
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
step()    { echo -e "\n${BLUE}=== $* ===${NC}"; }

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   error "此脚本需要 root 权限运行"
   echo "请使用: sudo bash $0"
   exit 1
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

step "步骤 1/9：检查系统环境"

ARCH=$(dpkg --print-architecture)
info "系统架构: $ARCH"
if [[ "$ARCH" != "amd64" ]]; then
    error "仅支持 amd64 架构"
    exit 1
fi
info "系统检测通过"

step "步骤 2/9：添加 i386 架构"

if ! dpkg --print-foreign-architectures | grep -q "i386"; then
    dpkg --add-architecture i386
    info "已添加 i386 架构"
else
    info "i386 架构已存在"
fi

step "步骤 3/9：安装中文字体依赖"

apt-get install -y fonts-wqy-microhei
info "中文字体已安装"

step "步骤 4/9：添加 Deepin Wine 软件源"

# 添加 apt 源
tee /etc/apt/sources.list.d/deepin-wine.i-m.dev.list > /dev/null << "EOF"
deb [trusted=yes] https://deepin-wine.i-m.dev /
EOF
info "已添加软件源"

# 设置优先级（低于系统源）
tee /etc/apt/preferences.d/deepin-wine.i-m.dev.pref > /dev/null << "EOF"
Package: *
Pin: release l=deepin-wine
Pin-Priority: 400
EOF
info "已设置源优先级"

step "步骤 5/9：刷新软件源"

apt-get update
info "软件源已刷新"

step "步骤 6/9：下载企业微信相关包"

cd "$WORK_DIR"

info "下载 deepin-wine-helper..."
apt-get download deepin-wine-helper

info "下载 deepin-wine10-stable..."
apt-get download deepin-wine10-stable

info "下载企业微信主包（约 700MB，请耐心等待）..."
apt-get download com.qq.weixin.work.deepin

step "步骤 7/9：构建补丁包"

info "构建 dummy-libsane 补丁包..."
mkdir -p dummy-libsane/DEBIAN
cat > dummy-libsane/DEBIAN/control << "CONTROL"
Package: dummy-libsane
Version: 1.0
Architecture: all
Maintainer: wecom-installer
Description: Dummy package to provide libsane for deepin-wine
 Ubuntu's libsane1 does not declare Provides: libsane,
 which deepin-wine10-stable depends on.
Provides: libsane (= 1.0.24)
CONTROL
dpkg-deb --root-owner-group -b dummy-libsane dummy-libsane_1.0_all.deb

info "重新打包 deepin-wine10-stable（移除无法满足的依赖）..."
WINE_DEB=$(ls deepin-wine10-stable_*.deb | head -1)
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
# 调整版本号避免冲突
sed -i 's/^Version: 10.14deepin8/Version: 10.14deepin8patched1/' wine-repack/extracted/DEBIAN/control
dpkg-deb --root-owner-group -b wine-repack/extracted deepin-wine10-stable-patched.deb

info "重新打包 deepin-wine-helper（移除 deepin-elf-verify 依赖）..."
HELPER_DEB=$(ls deepin-wine-helper_*.deb | head -1)
mkdir -p helper-repack/extracted
dpkg-deb -R "$HELPER_DEB" helper-repack/extracted
# helper 依赖 deepin-elf-verify，但实际运行不需要
sed -i -e 's/, deepin-elf-verify (>= 1.1.10-1)//g' \
    helper-repack/extracted/DEBIAN/control
dpkg-deb --root-owner-group -b helper-repack/extracted deepin-wine-helper-patched.deb

step "步骤 8/9：安装所有包"

info "安装 dummy-libsane..."
dpkg -i dummy-libsane_1.0_all.deb

info "安装 deepin-wine10-stable（已补丁）..."
dpkg -i deepin-wine10-stable-patched.deb

info "安装 deepin-wine-helper（已补丁）..."
dpkg -i deepin-wine-helper-patched.deb

info "安装企业微信主包..."
dpkg -i com.qq.weixin.work.deepin_*.deb

info "修复依赖关系..."
apt-get install -f -y

info "安装音频运行时依赖..."
apt-get install -y libasound2-plugins libcapi20-3 || warn "部分音频依赖安装失败"

step "步骤 9/9：配置应用图标 & 锁定包"

# 配置 XDG_DATA_DIRS 让应用图标显示
tee /etc/profile.d/deepin-wine.i-m.dev.sh > /dev/null << "EOF"
XDG_DATA_DIRS=${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
for deepin_dir in /opt/apps/*/entries; do
    if [ -d "$deepin_dir/applications" ]; then
        XDG_DATA_DIRS="$XDG_DATA_DIRS:$deepin_dir"
    fi
done
export XDG_DATA_DIRS
EOF
info "已配置应用图标"

# 锁定关键包，防止 apt upgrade 破坏依赖
apt-mark hold deepin-wine10-stable deepin-wine-helper com.qq.weixin.work.deepin 2>/dev/null || true
info "已锁定关键包"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ 企业微信安装成功！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}下一步：${NC}"
echo -e "  1. ${BLUE}注销并重新登录${NC}（让应用图标生效）"
echo -e "  2. 在应用菜单中查找 ${BLUE}企业微信${NC}"
echo -e "  3. 或直接在终端运行："
echo -e "     ${BLUE}/opt/apps/com.qq.weixin.work.deepin/files/run.sh${NC}"
echo ""
echo -e "${YELLOW}提示：${NC}"
echo -e "  • 所有用户都可以使用（各自独立账号）"
echo -e "  • 已锁定 deepin-wine 相关包，请勿手动 apt upgrade 升级"
echo ""
