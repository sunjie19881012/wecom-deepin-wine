# 常见问题排查

## 安装相关问题

### Q: apt 报错 "无法满足依赖关系"

**症状：**
```
deepin-wine10-stable : 依赖: libsane (>= 1.0.24)
                       依赖: libcapi20-3
```

**原因：** Ubuntu 26.04 的 `libsane1` 没有声明 `Provides: libsane`。

**解决：** 必须使用本项目的补丁包：
1. 先装 `dummy-libsane` 补丁包
2. 使用重新打包的 `deepin-wine10-stable-patched.deb`
3. 不要用原始的 `deepin-wine10-stable_*.deb`

---

### Q: `apt-get install -f` 把已安装的包卸载了

**症状：** 安装好企业微信后，运行 `apt-get install -f` 导致企业微信被卸载。

**原因：** apt 认为依赖关系损坏，会自动移除无法满足依赖的包。

**解决：**
```bash
# 1. 先安装补丁版 deepin-wine10-stable
sudo dpkg -i packages/deepin-wine10-stable-patched.deb
# 2. 再修复依赖
sudo apt-get install -f -y
# 3. 重新安装企业微信
sudo dpkg -i com.qq.weixin.work.deepin_*.deb
# 4. 锁定包
sudo apt-mark hold deepin-wine10-stable deepin-wine-helper com.qq.weixin.work.deepin
```

---

### Q: deepin-elf-verify 依赖 libssl1.1 无法安装

**症状：**
```
deepin-elf-verify 依赖于 libssl1.1 (>= 1.1.1)
```

**原因：** Ubuntu 26.04 使用 libssl3，不再提供 libssl1.1。

**解决：** 强制安装跳过此依赖（不影响企业微信运行）：
```bash
sudo dpkg -i --force-depends deepin-elf-verify_*.deb
```

---

### Q: 下载企业微信主包失败或很慢

**原因：** 主包约 700MB，源服务器在国外或带宽限制。

**解决：** 耐心等待，或换网络环境下载。命令：
```bash
apt-get download com.qq.weixin.work.deepin
```

---

## 运行相关问题

### Q: 找不到企业微信图标

**解决：**
1. **注销重新登录**（让 `/etc/profile.d/deepin-wine.i-m.dev.sh` 生效）
2. 或在终端直接启动：
   ```bash
   /opt/apps/com.qq.weixin.work.deepin/files/run.sh
   ```

---

### Q: 启动后中文显示为方块/乱码

**解决：** 安装中文字体：
```bash
sudo apt-get install -y fonts-wqy-microhei fonts-wqy-zenhei fonts-noto-cjk
```

---

### Q: 没有声音

**解决：** 安装音频依赖：
```bash
sudo apt-get install -y libasound2-plugins libjack-jackd2-0
```

检查 PulseAudio 是否运行：
```bash
pulseaudio --check && echo "running" || pulseaudio --start
```

---

### Q: 输入法无法输入中文

**解决：** 配置环境变量（以 fcitx5 为例）：
```bash
# 在 ~/.bashrc 或 ~/.profile 添加
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
```

---

### Q: Wine 容器初始化失败

**症状：** 首次启动卡住或报错。

**解决：** 清除用户配置重试：
```bash
rm -rf ~/.deepinwine ~/.local/share/deepin-wine
# 重新启动企业微信
```

---

## 维护相关

### Q: 如何卸载企业微信

```bash
# 解除锁定
sudo apt-mark unhold deepin-wine10-stable deepin-wine-helper com.qq.weixin.work.deepin

# 卸载
sudo apt-get remove --purge com.qq.weixin.work.deepin deepin-wine10-stable deepin-wine-helper deepin-elf-verify dummy-libsane

# 清理源
sudo rm /etc/apt/sources.list.d/deepin-wine.i-m.dev.list
sudo rm /etc/apt/preferences.d/deepin-wine.i-m.dev.pref
sudo rm /etc/profile.d/deepin-wine.i-m.dev.sh

# 清理用户数据（每个用户各自执行）
rm -rf ~/.deepinwine
```

---

### Q: 如何更新企业微信

由于依赖问题需要补丁处理，**不要直接 `apt upgrade`**。请：
1. 先卸载旧版本
2. 重新运行安装脚本
