# 远程 LSP 通信链路与模块文档

> 适用场景：macbook-m1-pro 上的 Emacs 通过 TRAMP 打开 nixos-nuc 上的 Python 文件，使用远程 pyright 进行 LSP 分析。
> 最后更新：2026-05-24

---

## 零、概念速查

**LSP 协议**：编辑器（客户端）与语言服务器（服务端）之间的 JSON-RPC 协议，定义补全/跳转/诊断等请求格式。

**lsp-mode 里的"client"**：不是通信客户端，是一份连接配置（用什么命令、支持哪些 mode、本地还是远程）。

**pyright-tramp / ruff-tramp 等**：`lsp-auto-register-remote-clients=t` 时，lsp-mode 从每个本地客户端自动克隆生成的远程副本，命名规律是 `<name>-tramp`。

**pyright-remote**：lsp-pyright.el 手动注册的远程客户端，用 `lsp-tramp-connection`（pipe），无 shell prompt 污染问题。与 `pyright-tramp` 连接的是同一种服务端程序 `pyright-langserver`，只是启动方式不同。

**为什么禁用 pyright-tramp 但保留 ruff-tramp**：ruff 装在系统全局（nix），`ruff-tramp` 能直接找到可执行文件正常工作；pyright 只在 `.venv` 里，`pyright-tramp` 找不到或走了交互式 shell，JSON-RPC 流被 shell prompt 污染导致超时。

**两个服务器并行**：pyright-remote（补全/类型检查/跳转）+ ruff-tramp（lint/格式化），lsp-mode 同时与两个进程通信，功能叠加。

**语言服务器如何知道 Python 路径**：① lsp-mode 初始化时通过 `initializationOptions` 主动告知；② 服务器自己在远程探测（`.venv`、`pyrightconfig.json`、`VIRTUAL_ENV`、系统 PATH）。探测发生在远程机器上，找到的是远程 Python。

---

## 一、整体通信链路图

```
macbook-m1-pro (Emacs daemon)
│
│  Buffer: /ssh:nixos-nuc:/mnt/home/wd/.hikyuu/.../part.py
│  major-mode: python-ts-mode
│  lsp-mode 激活
│
│  ① lsp-mode 客户端选择
│     candidates: pyright-tramp(p=2,❌禁用), pyright-remote(p=1,✅)
│     selected: pyright-remote
│
│  ② lsp-mode 发起连接
│     lsp-tramp-connection
│     command: ("pyright-langserver" "--stdio")
│
└──[TRAMP: sshx/ssh] ──────────────────────────────────────────┐
                                                                │
   macOS 侧 Emacs 进程 (pid=92679)                             │
   /bin/sh -i   ← 这是 TRAMP 的 shell wrapper 进程            │
   connection-type: pipe  ← lsp-tramp-connection 正确用 pipe  │
   │                                                            │
   │  JSON-RPC over SSH stdio pipe                             │
   │                                                            │
   nixos-nuc (Linux/NixOS)                                     │
   │                                                            │
   │  TRAMP remote path:                                       │
   │    /home/wd/.nix-profile/bin/pyright-langserver           │
   │    → /nix/store/.../home-manager-path/bin/pyright-langserver
   │    → /nix/store/jijw6mdnfi49bxz1zysxd34fjxkcxp9k-pyright-1.1.407/
   │        lib/node_modules/pyright/langserver.index.js       │
   │                                                            │
   │  pyright-langserver 进程 (pid=287126, pts/36)             │
   │    node /nix/store/.../pyright-langserver --stdio         │
   │    Python 环境: /mnt/home/wd/.config/freqtrade/.venv/     │
   │                   bin/python (含 hikyuu 包)               │
   └──────────────────────────────────────────────────────────-─┘
```

---

## 二、模块职责拆解

### 2.1 macbook 侧（Emacs 进程内）

| 模块 | 文件 | 职责 |
|------|------|------|
| `lsp-mode` | straight/lsp-mode/lsp-mode.el | JSON-RPC 协议层，客户端注册/选择/生命周期 |
| `lsp-pyright` | straight/lsp-pyright/lsp-pyright.el | 注册 `pyright` / `pyright-remote` 客户端，管理 pyright 配置 |
| `lsp-auto-register-remote-clients` | lsp-mode 内置 | 自动从每个本地客户端生成 `<name>-tramp` 远程副本（**危险**，见§4） |
| `TRAMP` | Emacs 内置 | 提供透明远程文件访问，`start-file-process` 在远程启动进程 |
| `envrc` | straight/envrc | 对 TRAMP 路径激活 direnv（`envrc-remote=1`，支持 sshx method） |
| `init-core-runtime.el` | lisp/core/ | 本地定制：tramp-remote-path、客户端禁用逻辑、pyright 远程可执行文件查找 |

### 2.2 nixos-nuc 侧（远程进程）

| 进程/组件 | 说明 |
|-----------|------|
| `pyright-langserver --stdio` | LSP server 本体，node 进程，通信用 stdio pipe |
| nix profile pyright | `/home/wd/.nix-profile/bin/pyright-langserver` → nix store，由 home-manager 管理 |
| Python 解释器 | `/mnt/home/wd/.config/freqtrade/.venv/bin/python`（含 hikyuu） |
| `tramp-remote-path` 注入 | `~/.nix-profile/bin`、`/etc/profiles/per-user/wd/bin`、`/run/current-system/sw/bin` |

---

## 三、关键流程：LSP 客户端选择

### 3.1 已注册的 Python LSP 客户端（remote 文件视角）

```
server-id          priority   remote?   connection-type        状态
─────────────────  ─────────  ────────  ─────────────────────  ──────────────────
pyright-tramp      2          t         lsp-stdio-connection   ❌ 禁用（见§4）
pyright-remote     1          t         lsp-tramp-connection   ✅ 使用
pyright            2          nil       lsp-stdio-connection   自动过滤（非远程）
ruff-tramp         -2         t         auto-generated         ❌ 禁用
pylsp-tramp        ?          t         auto-generated         ❌ 禁用
... 其他                                                        ❌ 禁用
```

### 3.2 选择逻辑（lsp-mode 内部）

```
1. 过滤 major-mode 匹配的客户端
2. 过滤 remote? 与 file-remote-p 匹配的客户端
3. 过滤 lsp-disabled-clients（buffer-local）
4. 按 priority 降序，取最高优先级
→ 结果：pyright-remote (p=1)
```

### 3.3 禁用逻辑（init-core-runtime.el 中的 hook）

两个 hook 挂在 `python-mode-hook` / `python-ts-mode-hook`：

**`+wd/disable-extra-python-tramp-clients`**（无条件，只要是远程文件）
- 禁用：`pyright-tramp`（核心！）、`ruff-tramp`、`pylsp-tramp`、`pyls-tramp`、`semgrep-ls-tramp`、`ty-ls-tramp` 及其非 tramp 版

**`+wd/maybe-disable-pyright-on-tramp`**（条件：远程找不到 pyright-langserver 时）
- 禁用：`pyright`、`pyright-tramp`（用 `process-file sh -lc "command -v pyright-langserver"` 探测）

---

## 四、核心问题：pyright-tramp vs pyright-remote

### 4.1 pyright-tramp（❌ 有缺陷，已禁用）

```
来源: lsp-auto-register-remote-clients = t
      lsp-mode 自动从 pyright 客户端 copy 生成

连接方式: lsp-stdio-connection
          → TRAMP 的 start-file-process
          → 在远端启动 /bin/sh -i（交互式 shell）
          → shell 的 stdin/stdout 连接到 pts/N（伪终端）

问题:
  交互式 shell 会在 stdout 写入:
    - shell prompt（PS1）
    - login banner / motd
    - 其他初始化输出
  这些字节直接混入 JSON-RPC Content-Length 帧流，
  导致 lsp-mode JSON 解析失败，后续所有请求超时。

症状:
  - lsp-log 大量 *ERROR*: Unknown message
  - textDocument/hover 超时（Timeout while waiting for response）
  - pyright 日志："Received change text document command for closed file"
  - 诊断结果始终为 nil
```

### 4.2 pyright-remote（✅ 正确实现）

```
来源: lsp-pyright.el 手动注册

连接方式: lsp-tramp-connection
          command: ("pyright-langserver" "--stdio")
          make-process :connection-type pipe :file-handler t
          → TRAMP 使用 pipe（非 PTY），无 shell 中间层
          → pyright-langserver 直接读写 stdin/stdout

优势:
  - 纯 pipe 通信，无 shell prompt 污染
  - JSON-RPC 帧完整传输
  - 支持 Content-Length 分帧协议

进程拓扑（修复后）:
  macbook: Emacs → [SSH pipe] → nixos-nuc: pyright-langserver(pts/36)
  macbook侧 Emacs 进程 cmd: /bin/sh -i (TRAMP wrapper, pid=92679)
  nixos-nuc 侧实际进程: node .../pyright/langserver.index.js --stdio
```

---

## 五、Python 环境解析链路

```
lsp-pyright-locate-python()
  ↓
lsp-pyright-python-search-functions:
  1. lsp-pyright--locate-python-venv()
       locate-dominating-file default-directory ".venv/"
       → 从 TRAMP 路径向上遍历远程文件系统
       executable-find (f-expand "bin/python" venv) [remote=t]
  2. lsp-pyright--locate-python-python()
       executable-find "python" t   (lsp-pyright-prefer-remote-env=t)
       → 在远程 PATH 中查找
  ↓
结果: /mnt/home/wd/.config/freqtrade/.venv/bin/python
      （含 hikyuu 包，同时也是 freqtrade 环境）
  ↓
lsp-register-custom-settings 发送给 pyright:
  "python.pythonPath" → /mnt/home/wd/.config/freqtrade/.venv/bin/python
  "python.venvPath"   → ""（无 pyrightconfig.json）
```

**注**：`.hikyuu/hub_cache/` 目录下无 pyrightconfig.json / pyproject.toml / .venv，
pyright 的 Python 路径来自远程 PATH 中的第一个 python，即 freqtrade venv。
如需指定特定环境，在项目根目录创建 pyrightconfig.json：
```json
{ "pythonPath": "/path/to/target/python" }
```

---

## 六、关键变量全览

每个变量列出：含义 / 默认值 / 本机设置值 / 错误场景 / 正确值建议。

### 6.1 lsp-mode 核心变量

---

**`lsp-auto-register-remote-clients`**

| 项 | 值 |
|----|----|
| 含义 | 是否自动为每个本地客户端生成 `<name>-tramp` 远程副本 |
| 默认值 | `t` |
| 本机设置值 | `t`（未覆盖，继承默认） |
| 错误影响 | 自动生成的 `pyright-tramp` 使用 `lsp-stdio-connection`，通过交互式 shell 启动，shell prompt 污染 JSON-RPC 流 |
| 正确做法 | 保持 `t`，但在 hook 里把 `pyright-tramp` 加入 `lsp-disabled-clients`（已修复） |

---

**`lsp-response-timeout`**

| 项 | 值 |
|----|----|
| 含义 | 等待 LSP server 响应的超时秒数，超时后报错并可能重启 server |
| 默认值 | `10` |
| 本机设置值 | `10`（未覆盖） |
| 错误影响 | `pyright-tramp` 下因 JSON 解析失败不响应，所有请求在 10s 后超时 |
| 正确做法 | 远程 LSP 可适当调大（如 `30`），网络延迟高时避免误判超时 |

---

**`lsp-idle-delay`**

| 项 | 值 |
|----|----|
| 含义 | 停止输入后多少秒触发 LSP 重新分析（发送 `textDocument/didChange`） |
| 默认值 | `0.5` |
| 本机设置值 | `0.5`（未覆盖） |
| 注意 | 远程 LSP 有网络往返延迟，过小的值会频繁发送消息；可适当调大到 `1.0~2.0` |

---

**`lsp-enable-file-watchers`**

| 项 | 值 |
|----|----|
| 含义 | 是否启用 `workspace/didChangeWatchedFiles` 通知（监听磁盘文件变化） |
| 默认值 | `t` |
| 本机设置值 | `t`（未覆盖） |
| 错误影响 | pyright 在初始化时注册了 110 个目录的 watcher（包含中文路径），lsp-log 中出现大量 `*ERROR*: Unknown message`，是 watcher 通知解析时的编码问题 |
| 正确做法 | 对远程文件可设 `(setq-local lsp-enable-file-watchers nil)` 禁用，减少噪音 |

---

**`lsp-file-watch-threshold`**

| 项 | 值 |
|----|----|
| 含义 | 单个 workspace 监听文件数超过此值时给出警告 |
| 默认值 | `1000` |
| 本机设置值 | `1000`（未覆盖） |
| 注意 | hub_cache 目录有 110 个子目录，未超阈值，但中文路径引发解析异常 |

---

**`lsp-log-io`**

| 项 | 值 |
|----|----|
| 含义 | 是否把全部 JSON-RPC 消息记录到 `*lsp-log*` |
| 默认值 | `nil` |
| 本机设置值 | `nil`（未覆盖） |
| 调试时 | 临时 `(setq lsp-log-io t)` 可看到完整帧内容；注意远程 LSP 消息量大，性能有影响 |

---

**`lsp-diagnostics-provider`**

| 项 | 值 |
|----|----|
| 含义 | 诊断信息（错误/警告）显示后端 |
| 默认值 | `:auto`（优先 flycheck，fallback flymake） |
| 本机设置值 | `:auto` |
| 注意 | Doom Emacs 通常使用 flycheck；若诊断不显示先检查 flycheck 是否启用 |

---

**`lsp-completion-provider`**

| 项 | 值 |
|----|----|
| 含义 | 补全后端 |
| 默认值 | `:none`（不强制，由 company/corfu 自动集成） |
| 本机设置值 | `:none` |

---

**`lsp-disabled-clients`**（buffer-local，part.py 中）

| 项 | 值 |
|----|----|
| 含义 | 对当前 buffer 禁用的 LSP 客户端列表 |
| 默认值 | `nil`（全局） |
| part.py 中的实际值 | `(pyright-tramp semgrep-ls-tramp ruff-tramp ty-ls-tramp pylsp-tramp pyls-tramp semgrep-ls ruff ty-ls pylsp pyls)` |
| 设置时机 | `python-ts-mode-hook` → `+wd/disable-extra-python-tramp-clients` |
| 关键点 | `pyright-tramp` 必须在此列表中，否则它的优先级 (2) 高于 `pyright-remote` (1)，会抢占连接 |

---

### 6.2 lsp-pyright 变量

---

**`lsp-pyright-langserver-command`**

| 项 | 值 |
|----|----|
| 含义 | pyright LSP server 的可执行文件名（不含 `-langserver` 后缀） |
| 默认值 | `"pyright"` |
| 本机设置值 | `"pyright"` |
| 实际命令 | `pyright-langserver --stdio`（`lsp-pyright-langserver-command` + `"-langserver"` + args） |

---

**`lsp-pyright-langserver-command-args`**

| 项 | 值 |
|----|----|
| 含义 | 传给 pyright-langserver 的额外参数列表 |
| 默认值 | `("--stdio")` |
| 本机设置值 | `("--stdio")` |

---

**`lsp-pyright-python-executable-cmd`**

| 项 | 值 |
|----|----|
| 含义 | 在 PATH 中查找 Python 解释器时使用的命令名 |
| 默认值 | `"python"` |
| 本机设置值 | `"python"` |
| 注意 | 多数 Linux 系统 `python` 不存在，只有 `python3`；若找不到 Python 则 pyright 用系统默认解释器分析，类型信息可能不准 |

---

**`lsp-pyright-prefer-remote-env`**

| 项 | 值 |
|----|----|
| 含义 | 为 `t` 时，`executable-find` 调用加 `remote=t` 参数，在远程主机 PATH 中查找 Python（Emacs 27+） |
| 默认值 | `t` |
| 本机设置值 | `t` |
| 正确值 | `t`（必须，否则找到的是 macbook 本地的 Python，路径发给远程 pyright 后找不到文件） |

---

**`lsp-pyright-venv-path`**

| 项 | 值 |
|----|----|
| 含义 | 显式指定 venv 根路径（覆盖自动探测） |
| 默认值 | `nil` |
| 本机设置值 | `nil` |
| 建议 | 对 hub_cache 项目，可 dir-local 设为 freqtrade venv 路径，或创建 pyrightconfig.json |

---

**`lsp-pyright-venv-directory`**

| 项 | 值 |
|----|----|
| 含义 | venv 目录名（从项目根目录向上找此名称的目录） |
| 默认值 | `nil`（不用此机制） |
| 本机设置值 | `nil` |

---

**`lsp-pyright-multi-root`**

| 项 | 值 |
|----|----|
| 含义 | 是否以 multi-root workspace 模式启动（一个 server 服务多个 workspace root） |
| 默认值 | `t` |
| 本机设置值 | `t` |
| 注意 | multi-root 下 pyright 会对每个 workspace folder 发 `workspace/configuration` 请求；hub_cache 无 pyrightconfig.json 时 pyright 把整个 hub_cache 作为 root |

---

**`lsp-pyright-type-checking-mode`**

| 项 | 值 |
|----|----|
| 含义 | 类型检查严格级别 |
| 可选值 | `"off"` / `"basic"` / `"standard"` / `"strict"` |
| 默认值 | `"standard"` |
| 本机设置值 | `"standard"` |

---

**`lsp-pyright-diagnostic-mode`**

| 项 | 值 |
|----|----|
| 含义 | 诊断分析范围 |
| 可选值 | `"openFilesOnly"` / `"workspace"` |
| 默认值 | `"openFilesOnly"` |
| 本机设置值 | `"openFilesOnly"` |
| 注意 | `"workspace"` 会分析所有文件（包括未打开的），远程大项目下会显著增加 CPU 和内存消耗 |

---

**`lsp-pyright-log-level`**

| 项 | 值 |
|----|----|
| 含义 | pyright server 自身的日志级别 |
| 可选值 | `"error"` / `"warning"` / `"info"` / `"trace"` |
| 默认值 | `"info"` |
| 本机设置值 | `"info"` |
| 调试时 | 改为 `"trace"` 可看到 pyright 内部详细日志，在 `*pyright-remote::stderr*` buffer 里 |

---

**`lsp-pyright-python-search-functions`**

| 项 | 值 |
|----|----|
| 含义 | 按顺序尝试的 Python 查找函数列表，第一个非 nil 结果作为 `python.pythonPath` |
| 默认值 | `(lsp-pyright--locate-python-venv lsp-pyright--locate-python-python)` |
| 本机设置值 | 同默认 |
| 查找顺序 | ① `locate-dominating-file` 从 buffer 路径向上找 `.venv/` → `executable-find bin/python`<br>② `executable-find "python" t`（远程 PATH） |
| 本机结果 | `/mnt/home/wd/.config/freqtrade/.venv/bin/python`（由 PATH 或 .venv 探测到） |

---

### 6.3 TRAMP 变量

---

**`tramp-remote-path`**

| 项 | 值 |
|----|----|
| 含义 | 远程主机上 PATH 的搜索顺序，TRAMP 在此列表中依次查找可执行文件 |
| 默认值 | `(tramp-default-remote-path "/bin" "/usr/bin" "/sbin" "/usr/sbin" ...)` |
| 本机设置值（实际完整值）| `("/etc/profiles/per-user/wd/bin"` ← 最高优先<br>`"~/.nix-profile/bin"`<br>`tramp-own-remote-path` ← 继承远端 $PATH<br>`"/run/wrappers/bin"`<br>`"/run/current-system/sw/bin"`<br>`tramp-default-remote-path` ← TRAMP 默认<br>`"/bin" "/usr/bin" "/sbin" ...`)` |
| 关键项 | `tramp-own-remote-path`：继承远端 shell 实际 $PATH；nix 路径确保找到 `pyright-langserver` |
| 设置位置 | `init-core-runtime.el` → `(after! tramp ...)` |

---

**`tramp-connection-timeout`**

| 项 | 值 |
|----|----|
| 含义 | TRAMP 建立连接的超时秒数 |
| 默认值 | `60` |
| 本机设置值 | `60`（未覆盖） |

---

**`tramp-use-ssh-controlmaster-options`**

| 项 | 值 |
|----|----|
| 含义 | 是否让 TRAMP 在 SSH 命令中附加 ControlMaster 选项（连接复用） |
| 默认值 | `t` |
| 本机设置值 | `t` |
| 注意 | `lsp-tramp-connection` 的 SSH 进程命令为 `ssh -q -o ControlMaster=no -o ControlPath=none`，**主动禁用**了 ControlMaster，每次 LSP 连接独立建立 SSH session，避免 ControlMaster 超时导致 LSP 断开 |

---

**`tramp-default-method`**

| 项 | 值 |
|----|----|
| 含义 | 未指定 method 时的默认 TRAMP 传输方式 |
| 默认值 | `"scp"` |
| 本机设置值 | `"scp"`（未覆盖） |
| 本机实际使用 | `ssh`（`/ssh:nixos-nuc:...`）和 `sshx`（`/sshx:nixos-nuc:...`，自定义方法） |

---

**`vterm-tramp-shells`**（相关，见 init-tools-misc.el）

| 项 | 值 |
|----|----|
| 含义 | vterm 在各 TRAMP method 下使用的 shell |
| 本机设置值 | `sshx/ssh/scp` → `login-shell /bin/zsh /bin/bash` |
| 与 LSP 关系 | 无直接关系，但 `sshx` method 需在此声明才能在 vterm 中使用 |

---

### 6.4 envrc 变量

---

**`envrc-remote`**

| 项 | 值 |
|----|----|
| 含义 | 非零时对远程 TRAMP 路径也激活 envrc/direnv |
| 默认值 | `nil`（不处理远程） |
| 本机设置值 | `1`（全局启用远程 envrc） |
| 与 LSP 关系 | 若远程项目有 `.envrc` 激活了 Python venv，envrc 会修改远程 PATH，影响 `lsp-pyright-locate-python` 找到的 Python |

---

**`envrc-supported-tramp-methods`**

| 项 | 值 |
|----|----|
| 含义 | envrc 支持的 TRAMP method 列表 |
| 默认值 | `("ssh" "scp" ...)` |
| 本机设置值 | 追加了 `"sshx"`（`cl-pushnew "sshx" ...`） |

---

### 6.5 变量速查：错误值 vs 正确值对照

| 变量 | 错误值（或危险值） | 正确值（本机） | 后果说明 |
|------|-----------------|--------------|---------|
| `lsp-auto-register-remote-clients` | `t`（不加防护） | `t` + hook 禁用 `pyright-tramp` | 自动生成的 `*-tramp` 客户端会抢占 `pyright-remote` |
| `lsp-disabled-clients`（buffer-local） | `nil` 或不含 `pyright-tramp` | 含 `pyright-tramp` | 导致使用错误客户端，JSON-RPC 流损坏 |
| `lsp-pyright-prefer-remote-env` | `nil` | `t` | 在 macbook 上查找 Python，路径发给远程 pyright 后找不到 |
| `lsp-pyright-python-executable-cmd` | `"python3"`（nixos-nuc 无 `python3` 裸命令时） | `"python"` | 找不到 Python 时 pyright 用默认解释器 |
| `lsp-pyright-diagnostic-mode` | `"workspace"`（大项目） | `"openFilesOnly"` | 远程大 workspace 触发全量分析，CPU/内存暴涨 |
| `tramp-remote-path` | 不含 nix 路径 | 含 `~/.nix-profile/bin` 等 | 找不到 `pyright-langserver`，LSP 无法启动 |
| `lsp-enable-file-watchers` | `t`（中文路径项目） | 可设为 `nil` | 中文路径 watcher 通知引发 lsp-log `*ERROR*: Unknown message` |

---

## 七、遗留问题

| 问题 | 说明 | 影响 |
|------|------|------|
| 孤儿进程 168001 | May23 的 npm pyright（`/home/wd/.config/emacs/.local/etc/lsp/npm/pyright/`），Emacs session 退出后未清理 | 占用内存 ~433MB，可手动 kill |
| 孤儿进程 283384 | 今日修复前用错误方式（pyright-tramp）启动的 nix pyright，pts/9 | 同上，可手动 kill |
| 无 pyrightconfig.json | hub_cache 项目无 pyright 配置，Python 环境靠 PATH 自动探测 | pyright 可能用错环境 |
| workspace-folders = nil | pyright-remote 连接后 workspace folder 未注册（multi-root=nil?） | 跨文件跳转/分析范围受限 |

---

## 七、关键配置位置

```
~/.config/emacs.d/
├── lisp/core/init-core-runtime.el   # 远程 LSP 全部定制逻辑
│   ├── tramp-remote-path 配置
│   ├── +wd/disable-extra-python-tramp-clients  (禁用 pyright-tramp 等)
│   ├── +wd/maybe-disable-pyright-on-tramp      (无 pyright 时完全禁用)
│   └── +wd/lsp-pyright-use-remote-command-a    (advice: lsp-package-path)
│
~/.config/emacs/.local/straight/
├── build-30.2.50/lsp-mode/lsp-mode.el
│   └── lsp-auto-register-remote-clients  (t → 自动生成 pyright-tramp)
└── build-30.2.50/lsp-pyright/lsp-pyright.el
    ├── pyright        (local, p=2, lsp-stdio-connection)
    ├── pyright-remote (remote, p=1, lsp-tramp-connection)  ← 正确客户端
    └── lsp-pyright-locate-python  → python.pythonPath
```
