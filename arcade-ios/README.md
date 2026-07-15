# Mini Arcade — iOS App（上架 App Store）

把 `../games` 的网页小游戏合集，用 [Capacitor](https://capacitorjs.com/) 包成一个
**原生 iOS App**：

- **离线可玩**：8 个游戏全部打包进 App，无网也能玩（对标「Offline Games – No Wifi」）。
- **在线更新游戏**：新游戏只要发布到你的网页地址，App 下次打开就会自动多出来，**不用重新提交 App Store**（详见下方「在线更新」）。
- **原生外壳**：全屏、启动图、App 图标、可安装，符合审核要求。

> ⚠️ **必须在 Mac 上完成打包和提交。** 需要：一台 Mac、Xcode、Apple
> Developer 账号（$99/年）、Node.js、CocoaPods。这一步在 Linux/云端无法进行——
> 本目录已经把「能提前做的」都做好了，你在 Mac 上跑几条命令即可。

---

## 一、准备（Mac 上，一次性）

```bash
# 1. 安装 Xcode（App Store 里下载）后，安装命令行工具
xcode-select --install

# 2. 安装 CocoaPods（Capacitor iOS 依赖它）
sudo gem install cocoapods
#   Apple Silicon 如报错可用： brew install cocoapods

# 3. 安装 Node.js（若没有）： https://nodejs.org  （建议 18+）
```

## 二、生成 Xcode 工程

```bash
cd arcade-ios

# 安装依赖
npm install

# 把网页游戏拷进 www/ 并生成 iOS 原生工程
npm run add:ios

# 生成 App 图标（用 resources/icon.png）
npm run assets

# 用 Xcode 打开
npm run open
```

> 每次改了游戏（`../games` 里的内容）后，重新同步一次即可：
> ```bash
> npm run sync
> ```

## 三、在 Xcode 里设置并提交

1. 左侧选中项目 **App** → **Signing & Capabilities**：
   - **Team**：选你的 Apple Developer 账号。
   - **Bundle Identifier**：改成你自己的，例如 `com.你的名字.miniarcade`
     （要和后面 App Store Connect 里创建的一致）。
2. **General** → 设置 **Display Name**、**Version**（如 `1.0.0`）、**Build**（如 `1`）。
3. 顶部机型选 **Any iOS Device (arm64)** → 菜单 **Product ▸ Archive**。
4. Archive 完成后在 Organizer 里点 **Distribute App ▸ App Store Connect ▸ Upload**。
5. 打开 [App Store Connect](https://appstoreconnect.apple.com) → **我的 App ▸ +**
   创建 App（Bundle ID 选上面那个）→ 填写名称、截图、隐私、分级 → 选择刚上传的
   构建版本 → **提交审核**。

截图可以用模拟器：Xcode ▸ **Product ▸ Run**（选 iPhone 15 Pro 等），
用 **⌘S** 截图，尺寸符合 App Store 要求（6.7"/6.5" 等）。

---

## 四、在线更新游戏（核心）🔄

App 里的游戏目录来自一个 **manifest（清单）**。原理：

- App 内**打包**了 8 个游戏的清单与代码 → 离线基础包。
- 打开 App 时，如果有网，会去你的**网页地址**读取最新清单，把里面**新增的游戏**
  合并进来（新游戏的代码从网页按需加载）。
- 因为这些都是 WebView 里的「解释型内容」（HTML/JS），**Apple 允许这样更新，
  不需要重新提交 App**（App Store 审核指南 3.3.2）。

### 怎么发布新游戏（不用再上架）

1. 把网页版部署到一个公开地址。最简单用 **GitHub Pages**：
   仓库 **Settings ▸ Pages ▸ Source = main**，路径就是
   `https://<用户名>.github.io/<仓库>/games/`。
2. 打包 App 时把这个地址填进去（默认已填 `https://ycymycym.github.io/docs/games`）。
   要改的话：
   ```bash
   CAP_REMOTE_BASE="https://你的用户名.github.io/你的仓库/games" npm run sync
   ```
3. 以后要加新游戏，只需在网页仓库里：
   - 在 `games/js/games/` 加一个新模块（导出 `mount(root, api)`，见 `../games/README.md`）。
   - 在 `games/manifest.json` 的 `games` 数组里加一条，并把 `version` 号 +1。
   - 推送 / 部署。
4. 用户的 App 下次联网打开就会自动出现新游戏，并弹出「🎉 新游戏已添加」。

> **什么时候仍需重新提交 App？** 只有当你改动**原生外壳本身**（App 图标、名称、
> 权限、Capacitor 版本、启动图等）时才需要重新 Archive 上传。纯游戏内容更新不需要。

---

## 五、审核小贴士

- 本 App 打包了完整可离线游玩的内容 + 原生外壳，满足「最低功能」要求（指南 4.2），
  不是「套壳网站」。
- 在线更新只更新 WebView 内的解释型内容，符合指南 3.3.2。
- 年龄分级选 **4+**；若无三方广告/追踪，隐私填「不收集数据」即可
  （本项目默认不收集任何数据，分数只存在设备本地 `localStorage`）。

## 目录说明

```
arcade-ios/
├── package.json            # 依赖与命令
├── capacitor.config.json   # appId / appName / webDir
├── resources/icon.png      # 1024×1024 App 图标源（npm run assets 会用它）
├── scripts/prepare-web.mjs # 把 ../games 拷进 www/ 并注入在线更新地址
├── www/                    # 生成物（已 gitignore）
└── ios/                    # 生成的 Xcode 工程（已 gitignore；npm run add:ios 生成）
```
