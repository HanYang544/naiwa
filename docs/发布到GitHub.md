# 下载与更新奶娃桌面宠物

现有项目仓库：[HanYang544/naiwa](https://github.com/HanYang544/naiwa)。当前默认分支为 `agent/unify-naiwa-proportions`，最新版程序、动作素材和预览在此分支更新。

## 下载后直接运行

1. 打开仓库首页，选择 **Code → Download ZIP**。
2. 解压整个压缩包，保持程序文件与 `assets` 文件夹的相对位置。
3. 双击 **启动奶娃桌面宠物.bat**。

普通运行无需安装 Git、GitHub CLI、Python 或 Node.js。

## 获取可提交更新的工作副本

维护者需要本机已有 Git，并具备本仓库的推送权限。在准备存放项目的目录中执行：

```cmd
git clone --branch agent/unify-naiwa-proportions https://github.com/HanYang544/naiwa.git
cd naiwa
```

从 ZIP 解压得到的目录通常没有 `.git`，不能在该目录直接执行 `git push`。请先克隆现有仓库，再将需要更新的程序、素材和文档复制到这个 Git 工作副本中。

## 提交更新到现有分支

在 Git 工作副本中，开始修改前先同步当前分支：

```cmd
git switch agent/unify-naiwa-proportions
git pull --ff-only origin agent/unify-naiwa-proportions
```

修改完成并确认程序运行正常后，检查待提交文件，再提交和推送：

```cmd
git status --short
git add .
git commit -m "更新奶娃桌面宠物形象与动画"
git push origin agent/unify-naiwa-proportions
```

若首次提交提示 Git 身份未配置，请设置你自己的提交用户名与邮箱后，再执行提交。

## 发布内容与检查

仓库包含主程序、13 组共 156 张正式动画帧、原始形象参考、本轮素材表与提示词、中文说明、预览图及自动检查配置。制作过程中的临时文件、运行日志和回退备份保存在项目之外。

每次推送后，GitHub Actions 会检查主程序的 PowerShell 语法，以及日常 60 帧和搞怪 96 帧是否齐全。可在仓库的 **Actions** 页面查看结果。
