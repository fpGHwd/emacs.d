# Troubleshooting

## Emacs 响应系统 fcitx-rime 输入法

Symptom: Emacs（PGTK build）自动响应系统 fcitx-rime，需要手动切换英文输入法。

Cause: GTK Emacs 读取 `GTK_IM_MODULE` 环境变量，自动加载系统输入法模块。

Fix: 在 `~/.config/emacs.d/config.el` 或 `early-init.el` 开头清除该变量：

```elisp
(setenv "GTK_IM_MODULE" nil)
```

之后重启 Emacs。内部 `emacs-rime`（通过 `M-\` 手动激活）不受影响。


## Go tree-sitter highlighting is sparse

Symptom: Go buffers in `go-ts-mode` show only sparse highlighting, such as
comments, while keywords like `package`, `import`, `const`, `type`, and `func`
remain uncolored.

Confirmed cause: Emacs 30.2 `go-ts-mode` font-lock queries can be incompatible
with newer `tree-sitter-go` grammars. In this failure mode, `font-lock-ensure`
raises a `treesit-query-error` with `Query pattern is malformed`.

Current fix: pin the Go grammar in `lisp/init-langs.el`:

```elisp
(after! treesit
  (setf (alist-get 'go treesit-language-source-alist)
        '("https://github.com/tree-sitter/tree-sitter-go" "v0.23.4" nil nil nil)))
```

After reinstalling or replacing `libtree-sitter-go.so`, restart the
systemd-managed Emacs server:

```bash
systemctl --user restart emacs
```

`doom/reload` and `load-file` are not sufficient for this verification because
tree-sitter grammar `.so` files remain loaded in the Emacs process.
