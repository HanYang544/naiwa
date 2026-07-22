# 发布到 GitHub 公共仓库

## 准备工作

确认已经安装并登录 GitHub CLI：

```cmd
gh --version
gh auth status
```

如果尚未登录：

```cmd
gh auth login
```

## 一键创建并推送公共仓库

在 CMD 或 PowerShell 中进入本项目文件夹，然后执行：

```cmd
cd "奶娃桌面宠物-GitHub发布版"
git init -b main
git add .
git commit -m "发布奶娃桌面宠物"
gh repo create naiwa-desktop-pet --public --source=. --remote=origin --push
```

完成后，GitHub CLI 会输出公共仓库地址。

## 如果提示 Git 身份未配置

将下面的信息改为你自己的 GitHub 用户名和邮箱：

```cmd
git config user.name "你的GitHub用户名"
git config user.email "你的GitHub邮箱"
git commit -m "发布奶娃桌面宠物"
```

## 如果仓库名称已经存在

将命令中的 `naiwa-desktop-pet` 换成其他名称，例如：

```cmd
gh repo create naiwa-pet-windows --public --source=. --remote=origin --push
```

## 后续更新

修改项目后执行：

```cmd
git add .
git commit -m "更新奶娃桌面宠物"
git push
```

公开仓库会包含程序、13 组共 156 张正式动画帧、中文说明、预览图和自动检查配置，不包含制作过程中的临时文件或旧版素材。
