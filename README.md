# dotfiles

这是一个面向 macOS 的个人开发环境配置仓库，用来统一管理 Shell、
Git、Tmux、Neovim、WezTerm 以及 Homebrew 软件清单。

仓库通过 `stow` 将配置链接到用户目录，并通过 `install-mac.sh` 完成
安装、同步、恢复和初始化。

**✨ 项目作用**

- 统一管理常用配置文件，避免手动散落修改。
- 用 `brew-file` 恢复 Homebrew 的 taps、brew、cask、go、cargo 工具。
- 用 Git submodule 管理独立演进的 `nvim` 和 `wezterm` 配置。
- 用 `install-mac.sh` 自动完成初始化、更新与配置落地。


**🧩 目录说明**

- `.zshrc`、`.zprofile`、`.zshenv`：Zsh 环境与交互配置
- `.gitconfig`：Git 别名、分页器、凭据等配置
- `.tmux.conf`：Tmux 快捷键、主题和插件配置
- `.config/nvim`：Neovim 子模块配置
- `.config/wezterm`：WezTerm 子模块配置
- `brew-file`：Homebrew 恢复文件，脚本会用 `brew bundle` 导入
- `install-mac.sh`：macOS 初始化和更新脚本


**🚀 安装方式**

推荐先克隆仓库，再执行脚本：

```bash
git clone --recurse-submodules https://github.com/Monkeyman520/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install-mac.sh
```

脚本默认会做这些事情：

1. 安装或初始化 Homebrew
2. 安装基础命令行工具
3. 安装或更新 oh-my-zsh
4. 安装或更新常用插件
5. 同步 `dotfiles` 仓库和 submodule
6. 从 `brew-file` 恢复 Homebrew 软件
7. 使用 `stow` 将配置应用到用户目录
8. 用 headless 模式预热 Neovim


**🔍 安全验证方式**

如果你想先验证脚本行为，不要直接动真实用户目录，建议这样执行：

```bash
DRY_RUN=1 TEST_HOME=/tmp/dotfiles-test bash install-mac.sh
```

这会：

- 只打印将执行的命令
- 把 `HOME` 切到临时目录
- 跳过真实的登录 shell 修改

如果只设置 `TEST_HOME`，不设置 `DRY_RUN=1`，那么 `brew install` 这类
系统级操作仍然会真实执行。


**⚙️ 可用环境变量**

- `DRY_RUN=1`
  只打印命令，不真正执行
- `TEST_HOME=/tmp/some-dir`
  把目标用户目录切到测试路径
- `BREWFILE_PATH=/path/to/brew-file`
  指定自定义 Homebrew 恢复文件

脚本默认优先读取：

1. `BREWFILE_PATH`
2. `$HOME/dotfiles/brew-file`
3. 仓库根目录下的 `brew-file`


**🛠️ 手动更新**

如果仓库已经存在，可以直接更新：

```bash
cd ~/dotfiles
git pull --recurse-submodules
git submodule update --init --recursive
bash install-mac.sh
```


**📌 说明**

- 这个仓库主要针对 macOS。
- `install-mac.sh` 会尝试修改默认登录 shell 为 `zsh`。
- `stow --adopt` 会把目标文件纳入仓库管理，执行前建议确认本地改动。
