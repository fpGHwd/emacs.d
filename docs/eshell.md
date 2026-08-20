# Eshell

Eshell 是 Emacs 内置的纯 Elisp shell，无需外部终端进程。

## 主要用途

- **混合 Shell 和 Elisp**：直接执行 shell 命令和 Elisp 表达式，结果互相传递
  ```elisp
  echo (+ 1 2 3)          # 输出 6
  find-file (list "/etc/passwd")
  ```

- **跨平台**：Windows 上也能用 `ls`, `grep`, `find` 等命令（由 Elisp 模拟实现）

- **与 Emacs 深度集成**：
  - 命令输出是 buffer 文本，可直接搜索/编辑/复制
  - `find-file` 等命令直接打开文件到 Emacs
  - 异步执行，不阻塞 Emacs

- **可编程**：可用 Elisp 写 alias、自定义命令、重定向到 buffer/变量

## 与 vterm/term 的区别

| 特性 | Eshell | vterm / term |
|------|--------|-------------|
| 实现 | 纯 Elisp 仿真 | 真正的终端仿真器 |
| TUI 程序 | 不支持 `htop`, `vim`, `tmux` | 完全支持 |
| 启动速度 | 快 | 较慢 |
| Emacs 集成 | 最深 | 一般 |

## 使用建议

- 不需要 TUI 程序时，用 `M-x eshell` 作为轻量级替代
- 需要 `htop`/`vim`/`tmux` 时，用 `vterm`（已在本配置中启用）
