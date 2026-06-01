# worktree-workspace

一个 Claude Code 插件，用于创建**立即可运行**的完整 git worktree 工作环境。

> [English](README.md)

---

## 为什么需要这个插件？

`git worktree add` 只检出 **git 追踪的文件**。以下内容都**不会被带过去**：

| 缺失的内容 | 后果 |
|-----------|------|
| `.env` / `.env.development` 等配置文件 | 项目无法启动 |
| `.idea/` / `.vscode/` 等 IDE 配置 | 开发环境配置丢失 |
| 被父仓库 gitignore 的子仓库 | 关联项目缺失，无法联调 |
| 子仓库自己的 `.env` 等配置文件 | 子项目也无法启动 |

**结果就是**：每次 `git worktree add` 之后，你还需要手动复制一堆配置文件、重新 clone 子仓库，来回折腾才能让项目跑起来。

## 这个插件做什么？

**一键创建完整 workspace**。创建后立即可运行——无需 `npm install`，无需手动复制配置。不仅检出 git 追踪的文件，还自动：

- ✅ **递归处理嵌套 git 仓库** — 被父仓库 ignore 的子仓库也会创建对应的 worktree，所有子仓库在同一 feature 分支上
- ✅ **智能复制配置文件** — `.env`、`.idea/`、`.claude/` 等被 ignore 的配置文件原样复制到新 workspace
- ✅ **复制依赖目录** — `node_modules`、`vendor`、`.venv` 原样复制到 workspace，无需 `npm install`，创建后立即可运行。
- ✅ **区分目录类型** — 如果目录包含 git 跟踪文件，只复制其中被 ignore 的个别文件；如果整个目录都是 ignore 的，整体复制
- ✅ **中文文件名支持** — 正确处理包含中文等非 ASCII 字符的文件名
- ✅ **一键清理** — `/worktree-workspace:worktree-remove` 递归移除所有嵌套 worktree

### 对比

| | `git worktree add` | `worktree-workspace` |
|---|---|---|
| git 追踪的文件 | ✅ | ✅ |
| 被 ignore 的配置文件 (`.env` 等) | ❌ | ✅ 自动复制 |
| 嵌套子仓库及其 worktree | ❌ | ✅ 递归创建 |
| 子仓库的 ignore 配置文件 | ❌ | ✅ 一并复制 |
| IDE 配置目录 (`.idea/` 等) | ❌ | ✅ 自动复制 |
| `node_modules` / `vendor` | ❌ | ✅ 复制到 workspace，立即可运行 |
| 清理所有嵌套 worktree | ❌ 手动逐个删 | ✅ 一条命令 |

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/adamcjm/claude-code-worktree-workspace/main/install.sh | bash
```

插件会被 clone 到 `~/.claude/skills/worktree-workspace` — Claude Code v2.1.157+ 会自动发现该目录下的插件。完成后重启 Claude Code。

## 命令

以下命令均在 **Claude Code 对话中**执行。每个命令是 `worktree-workspace` 插件下的一个 skill，带命名空间。

### `/worktree-workspace:worktree-add` — 创建 workspace

```
/worktree-workspace:worktree-add <名称> [--prefix <分支前缀>] [--base <基准分支>]
```

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `名称` | *(必填)* | workspace 标识。目录创建在原仓库同级，命名为 `<仓库名>-<名称>` |
| `--prefix` | `feature` | 分支名前缀。分支名 = `<prefix>/<名称>`。如 `--prefix fix` 得到 `fix/<名称>`，`--prefix ""` 不加前缀 |
| `--base` | 当前 HEAD | 从哪个分支/commit 创建新分支。每个仓库独立解析 |

**分支命名**：workspace 中所有仓库（根仓库 + 所有子仓库）使用**相同的分支名**。比如执行 `/worktree-workspace:worktree-add order-export`，所有仓库都会创建 `feature/order-export` 分支。

**`--base` 行为**：不加 `--base` 时，每个仓库从**自己当前的 HEAD** 分叉——不同仓库可能基于不同的分支：

```
根仓库在 main       → feature/order-export 基于 main
API 仓库在 master    → feature/order-export 基于 master
Web 仓库在 dev       → feature/order-export 基于 dev
```

加了 `--base main`：所有仓库统一从 `main`（本地不存在则尝试 `origin/main`，都不存在则回退到 HEAD 并给出警告）。

**执行流程**：

1. 在当前仓库创建 worktree → `<仓库父目录>/<仓库名>-<名称>`
2. 列出所有被 gitignore 的文件/目录
3. 对每个 ignore 项：
   - 包含 `.git` 的目录 → 递归创建嵌套仓库 worktree（使用相同分支名）
   - 完全 ignore 的目录（如 `.idea/`）→ rsync 到 worktree
   - 部分跟踪的目录（如 `app/` 里只有个别 `.DS_Store`）→ 只复制被 ignore 的文件
   - 被 ignore 的依赖目录（`node_modules/`、`vendor/`、`.venv/`）→ rsync 到 worktree
   - ignore 的文件（如 `.env`）→ 复制到 worktree
   - 构建产物和缓存（`.next/`、`dist/`、`build/`、`__pycache__/`、`.DS_Store` 等）→ 跳过

示例：

```
# 开始新功能（每个仓库从自己的 HEAD 分叉）
/worktree-workspace:worktree-add order-export

# 从 main 创建 bug 修复分支，所有仓库统一从 main
/worktree-workspace:worktree-add login-error --prefix fix --base main

# 不加前缀，直接用名称做分支
/worktree-workspace:worktree-add experiment --prefix ""
```

执行输出：

```
Setting up workspace: ~/projects/myapp-order-export
  Branch: feature/order-export

  Creating worktree: .../myapp-order-export
  Creating worktree: .../myapp-order-export/api
  Creating worktree: .../myapp-order-export/web
    Copied: .env
    Copied: .env.development
    Copying dir: .idea/

Workspace ready: ~/projects/myapp-order-export
```

### `/worktree-workspace:worktree-list` — 查看 workspace

```
/worktree-workspace:worktree-list
```

列出当前仓库的所有 workspace，显示分支名和嵌套子仓库。

输出：

```
Workspaces for myapp:

  order-export                   feature/order-export
    └─ api                       feature/order-export
    └─ web                       feature/order-export
  login-error                    fix/login-error
    └─ api                       fix/login-error
    └─ web                       fix/login-error
```

### `/worktree-workspace:worktree-remove` — 清理 workspace

```
/worktree-workspace:worktree-remove <名称> [--delete-branches]
```

| 参数 | 说明 |
|------|------|
| `名称` | 创建时使用的 workspace 名称 |
| `--delete-branches` | 同时删除所有仓库中对应的分支 |

**执行流程**：

1. 定位 workspace 目录 `<仓库父目录>/<仓库名>-<名称>`
2. 从深层到浅层依次移除嵌套子仓库的 worktree
3. 移除根仓库 worktree
4. **彻底删除 workspace 目录**——包括所有非 git 文件（依赖、配置等）
5. 在每个仓库中执行 `git worktree prune` 清理残留引用
6. 如果指定了 `--delete-branches`：强制删除每个仓库中对应的分支

**默认不会删除分支。** `worktree-remove` 只移除 worktree 目录，分支依然保留。如需同时删除分支，使用 `--delete-branches`，或手动在各仓库中 `git branch -D feature/<名称>`。

示例：

```
# 移除 workspace，保留分支
/worktree-workspace:worktree-remove order-export

# 移除 workspace 并删除所有分支
/worktree-workspace:worktree-remove order-export --delete-branches
```

### `/worktree-workspace:worktree-help` — 用法帮助

```
/worktree-workspace:worktree-help
```

显示所有命令及其选项和示例。

### 完整工作流

`/` 开头的命令在 **Claude Code 中**输入，`$` 开头的是终端命令。

```
# 1. 创建独立 workspace
/worktree-workspace:worktree-add order-export

# 2. 在终端中进入 workspace 目录开发
$ cd ../myapp-order-export

# 3. 在原仓库目录再开一个 Claude Code 会话，并行开发
/worktree-workspace:worktree-add stock-report

# 4. 随时查看当前有哪些 workspace
/worktree-workspace:worktree-list

# 5. 移除 workspace（保留分支）
/worktree-workspace:worktree-remove order-export

# 6. 或彻底清理，包括删除分支
/worktree-workspace:worktree-remove order-export --delete-branches
```

## 适用场景

- **Monorepo / 多仓库项目** — 根仓库下放了多个独立 git 仓库，一起做 feature 时需要在每个子仓库开分支
- **配置文件不在 git 中** — `.env` 等敏感配置不方便提交 git，但又需要带到 worktree 里才能运行
- **并行开发多个需求** — 每个需求一个独立 workspace，互不干扰，切目录就是切上下文

## 原理

1. `git worktree add` 创建根仓库 worktree
2. `git ls-files --others --ignored --exclude-standard` 找出所有被 ignore 的内容
3. 对每个 ignore 项分类处理：
   - 包含 `.git` 的目录 → 递归创建嵌套仓库 worktree
   - 整个目录都是 ignore 的 → rsync 到 worktree（包括 `node_modules`、`vendor`、`.venv`）
   - 目录内有 git 跟踪文件 → 只复制其中被 ignore 的个别文件
   - 普通文件 → 复制到 worktree
   - 匹配跳过规则 → 不复制（构建产物、缓存等）
4. `worktree-remove` 按相反顺序逐一清理

## License

MIT
