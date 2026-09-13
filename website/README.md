# Codex Usage Meter 官网

地址：https://ccssyy888.github.io/codex-usage-meter/

静态 HTML/CSS 官网，附带原生 JavaScript 图片轮播。无需构建或外部依赖。页面使用相对资源路径，适配 GitHub Pages 项目子路径。

## 发布

GitHub Pages 使用 GitHub Actions 部署。向 main 推送 website/ 或 .github/workflows/pages.yml 的改动后自动部署，也可在 Actions 中手动运行 Deploy website。上传目录仅为 website/。

## 本地预览

在仓库根目录运行 `python3 -m http.server 8770 --bind 127.0.0.1 --directory website`，访问 http://127.0.0.1:8770/。

## 安装包

首屏唯一下载按钮直接指向本项目 GitHub Releases 的 v0.2.0 ZIP，网站不存储或代理安装包。版本说明与 SHA-256 校验文件指向相同版本。

每次发布新版 App 后，同步更新 index.html 中的版本号、安装包、版本说明、校验文件地址，与仓库 README 的公开版本一致。网站自身改动不影响安装产品，无需发布新版 App。

## 资源和验证

assets/product.jpg 来自仓库既有产品宣传图，画面额度为示例。页面在桌面、手机宽度下检查无溢出，安装说明支持键盘操作。外部安装包已验证 SHA-256 一致。

## 图文展示

首屏包含完整 Mac 桌面、收起状态、额度详情、入口对比四张图片。使用标签切换，支持键盘左右键、Home/End 和手机横滑；不自动轮播。JavaScript 不可用时，图片按顺序展示。

文案依据作者的小红书帖子《同样是点一下，我为什么选菜单栏？》（笔记 ID：6a583d75000000000503a862），突出菜单栏不占工作区、固定位置、集中查看额度、只支持 Codex。帖子旧版“不扫描日志”说法没有沿用：当前 v0.2.0 任务动画会读取运行中会话文件，详细范围继续链接 PRIVACY.md。

- assets/menubar.jpg：仓库 docs/images/menu-bar-collapsed-v0.1.4.jpg。
- assets/quota-panel.png：仓库 docs/images/overview-zh-cn-v0.2.0.png。
- assets/placement-comparison.jpg：小红书对比图的无文字底图 marketing/xiaohongshu/v4-menubar-comparison-base.png，仅转换格式；界面位置示意，不表示另一款软件的实际界面。

旧宣传图上的编号、旧版本号和隐私断言不直接放入官网。完整安装说明锚点同步到当前 README 的“安装”章节。

本次验证：Chrome 中检查桌面、320px 与 390px 视图及图片切换、键盘切换；DOM 测试覆盖所有图片、循环导航、Home/End、焦点、触摸横滑与纵向滚动判别、取消手势和无 JavaScript 回退。
