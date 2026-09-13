# Codex Usage Meter 官网

地址：https://ccssyy888.github.io/codex-usage-meter/

静态 HTML/CSS 官网，原生 JavaScript 提供轮播交互，无构建或外部运行依赖。

## 发布与预览

向 main 推送 website/ 或 .github/workflows/pages.yml 的改动后，GitHub Actions 自动部署 website/；也可手动运行 Deploy website。

本地运行 `python3 -m http.server 8770 --bind 127.0.0.1 --directory website`，访问 http://127.0.0.1:8770/。

## 页面与交互

- 顶部使用应用自身图标、产品名与 macOS / 开源标识，不增加下载或导航入口。
- 图片采用横向滚动与 CSS scroll snap。触摸和触控板使用浏览器原生滚动，脚本增强鼠标拖动、键盘、前后按钮与状态提示；不自动播放。
- 左右方向键、Home/End 可操作图片；首尾按钮禁用。减少动态效果时使用即时定位。
- JavaScript 不可用时保留原生横向滚动，图片和对比文字仍可查看。
- 最后一页对比 Codex Usage Meter 与 CodexBar 的服务覆盖及适用场景，两者均为菜单栏工具。依据 [CodexBar 项目说明](https://github.com/steipete/CodexBar)，核对日期 2026-09-13。

## 素材来源

- assets/app-icon.png：由 Resources/AppIcon.icns 导出，缩至 128px。
- assets/product.jpg：仓库既有 Mac 实景宣传图。
- assets/menubar.jpg：docs/images/menu-bar-collapsed-v0.1.4.jpg。
- assets/quota-panel.png：docs/images/overview-zh-cn-v0.2.0.png。

产品画面为示例数据。文案参考作者的小红书帖子《同样是点一下，我为什么选菜单栏？》（笔记 ID：6a583d75000000000503a862），突出固定入口、不占工作区及 Codex 专用范围。旧版“不扫描日志”说法未沿用，任务动画的数据读取范围以 PRIVACY.md 为准。

## 下载

首屏唯一下载按钮直达 GitHub Releases 的 v0.2.0 ZIP，网站不存储或代理安装包。版本说明、校验文件对应同一版本。

发布新版 App 后同步更新 index.html 的版本号和相关链接，与仓库 README 保持一致。仅网站改动不影响安装产品，无需另发 App 版本。

## 本次验证

Chrome 中检查顶部、滑动视图和手机对比页。320、390、768px 下无页面横向溢出、顶部文字无碰撞、对比内容未裁切，定位最后一页正常。DOM 测试覆盖鼠标拖动与翻页阈值、取消与指针捕获释放、首尾边界、键盘、尺寸变化、减少动态效果、原生触摸/滚轮不被拦截，以及唯一下载入口。
