# Troubleshooting

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
