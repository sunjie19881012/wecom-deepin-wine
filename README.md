# Ubuntu 26.04 安装企业微信（Deepin Wine 版）

> 官方没有提供 Linux 版企业微信，本项目利用 Deepin 团队深度定制的 Wine 容器在 Ubuntu/Debian 系统上运行 Windows 版企业微信。

## ✨ 特性

- 📱 完整功能：消息、文件、语音/视频通话
- 🔊 支持音频（消息提醒、语音通话）
- 🖥️ 多用户共用：一次安装，所有用户可用（各自独立账号）
- 🎨 中文字体：内置文泉驿微米黑

## 📋 系统要求

- Ubuntu 24.04+ / Debian 12+（已在 Ubuntu 26.04 验证）
- x86_64 架构
- sudo 权限

## 🚀 快速安装

```bash
git clone https://github.com/sunjie19881012/wecom-deepin-wine.git
cd wecom-deepin-wine
sudo bash install.sh
```

安装完成后**注销重新登录**，即可在应用菜单中找到"企业微信"。

## 📖 实现原理

Ubuntu 26.04 上直接安装会遇到几个依赖问题，本项目通过以下方式解决：

### 问题 1：`libsane` 虚拟包未声明
Ubuntu 的 `libsane1` 包没有声明 `Provides: libsane`，而 `deepin-wine10-stable` 依赖它。
**解决**：创建一个 `dummy-libsane` 补丁包来提供这个虚拟包。

### 问题 2：`libssl1.1` 不存在
`deepin-elf-verify` 依赖 `libssl1.1`，但 Ubuntu 26.04 用的是 libssl3。
**解决**：强制安装 `deepin-elf-verify`，跳过此依赖（企业微信运行时不使用它）。

### 问题 3：apt 依赖冲突
上述问题导致 apt 处于"损坏"状态，无法安装其他包。
**解决**：重新打包 `deepin-wine10-stable`，移除无法满足的依赖声明。

## 📁 项目结构

```
.
├── README.md              # 本文件
├── install.sh             # 一键安装脚本
├── build-patch-packages.sh # 构建补丁包的脚本（可选）
├── packages/              # 预构建的补丁包
│   ├── dummy-libsane_1.0_all.deb
│   └── deepin-wine10-stable-patched.deb
└── docs/
    └── troubleshooting.md # 常见问题
```
## 🔧 手动安装

如果脚本无法使用，可手动安装：

```bash
# 1. 添加 i386 架构
sudo dpkg --add-architecture i386

# 2. 安装中文字体
sudo apt-get install -y fonts-wqy-microhei

# 3. 添加 Deepin Wine 源
sudo tee /etc/apt/sources.list.d/deepin-wine.i-m.dev.list > /dev/null << "EOF"
deb [trusted=yes] https://deepin-wine.i-m.dev /
EOF

# 4. 设置优先级
sudo tee /etc/apt/preferences.d/deepin-wine.i-m.dev.pref > /dev/null << "EOF"
Package: *
Pin: release l=deepin-wine
Pin-Priority: 400
EOF

# 5. 刷新源
sudo apt-get update

# 6. 下载各包
apt-get download deepin-wine-helper deepin-wine10-stable com.qq.weixin.work.deepin

# 7. 安装补丁包（解决 libsane 依赖）
sudo dpkg -i packages/dummy-libsane_1.0_all.deb

# 8. 安装主程序（使用修改后的包）
sudo dpkg -i packages/deepin-wine10-stable-patched.deb
sudo dpkg -i deepin-wine-helper_*.deb
sudo dpkg -i com.qq.weixin.work.deepin_*.deb

# 9. 安装运行时依赖
sudo apt-get install -y libasound2-plugins libcapi20-3

# 10. 配置应用图标
sudo tee /etc/profile.d/deepin-wine.i-m.dev.sh > /dev/null << "EOF"
XDG_DATA_DIRS=${XDG_DATA_DIRS:-/usr/local/share:/usr/share}
for deepin_dir in /opt/apps/*/entries; do
    if [ -d "$deepin_dir/applications" ]; then
        XDG_DATA_DIRS="$XDG_DATA_DIRS:$deepin_dir"
    fi
done
export XDG_DATA_DIRS
EOF

# 11. 锁定包，防止升级冲突
sudo apt-mark hold deepin-wine10-stable deepin-wine-helper com.qq.weixin.work.deepin
```

## ❓ FAQ

<details>
<summary><b>安装后找不到应用图标？</b></summary>

注销并重新登录，或者在终端直接启动：
```bash
/opt/apps/com.qq.weixin.work.deepin/files/run.sh
```
</details>

<details>
<summary><b>如何卸载？</b></summary>

```bash
sudo apt-mark unhold deepin-wine10-stable deepin-wine-helper com.qq.weixin.work.deepin
sudo apt-get remove --purge com.qq.weixin.work.deepin deepin-wine10-stable deepin-wine-helper dummy-libsane
```
</details>

<details>
<summary><b>多用户能否同时使用？</b></summary>

可以。企业微信安装到系统目录 `/opt/apps/`，每个用户的配置和数据分别保存在各自的 `~/.deepinwine/` 目录下，互不干扰。
</details>

<details>
<summary><b>如何更新？</b></summary>

先解除 hold，更新 deepin 源，再按本流程重新处理依赖。由于依赖问题需要补丁，**不要直接 `apt upgrade`**。
</details>

## ⚠️ 注意事项

1. 主包较大（~700MB），下载可能较慢
2. 包被 `hold`，不会被 `apt upgrade` 自动升级（避免依赖问题复发）
3. 本项目基于第三方 Deepin Wine 移植，非官方支持

## 🙏 致谢

- [deepin-wine-ubuntu](https://github.com/zq1997/deepin-wine) - Deepin Wine 的 Ubuntu 移植源
- [Deepin Team](https://www.deepin.org/) - Wine 容器定制
- [Tencent](https://work.weixin.qq.com/) - 企业微信
