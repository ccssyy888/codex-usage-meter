# Codex Usage Meter 官网

地址：https://ccssyy888.github.io/codex-usage-meter/

静态 HTML/CSS 官网。无需构建、JavaScript 或外部字体。页面使用相对资源路径，适配 GitHub Pages 项目子路径。

## 发布

GitHub Pages 使用 GitHub Actions 部署。向 main 推送 website/ 或 .github/workflows/pages.yml 的改动后自动部署，也可在 Actions 中手动运行 Deploy website。上传目录仅为 website/。

## 本地预览

在仓库根目录运行 `python3 -m http.server 8770 --bind 127.0.0.1 --directory website`，访问 http://127.0.0.1:8770/。

## 安装包

首屏唯一下载按钮直接指向本项目 GitHub Releases 的 v0.1.6 ZIP，网站不存储或代理安装包。版本说明与 SHA-256 校验文件指向相同版本。

每次发布新版 App 后，同步更新 index.html 中的版本号、安装包、版本说明、校验文件地址，与仓库 README 的公开版本一致。网站自身改动不影响安装产品，无需发布新版 App。

## 资源和验证

assets/product.jpg 来自仓库既有产品宣传图，画面额度为示例。页面在桌面、手机宽度下检查无溢出，安装说明支持键盘操作。外部安装包已验证 SHA-256 一致。
