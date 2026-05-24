;;; init-core-runtime.el --- Core runtime, remote, and lookup settings -*- lexical-binding: t; -*-

(use-package! auth-source
  :defer t
  :custom
  (auth-source-save-behavior 'ask)
  (auth-sources '("~/.config/emacs.d/etc/authinfo.gpg")))

(use-package! recentf
  :hook (doom-first-file-hook . recentf-mode)
  :config
  (setq recentf-max-saved-items 5000))

(use-package! eldoc
  :defer t
  :custom
  (eldoc-idle-delay 2))

(when (string= (system-name) "ubuntu2204")
  (after! doom
    (add-to-list '+lookup-provider-url-alist
                 '("Bing" "https://cn.bing.com/search?go=Search&q=%s&qs=ds&form=QBRE"))))

(after! doom
  (add-to-list '+lookup-provider-url-alist
               '("NixOS Package Search" "https://search.nixos.org/packages?channel=25.11&query=%s")))

(setq source-directory
      (pcase (system-name)
        ("macbook-m1-pro" "/sshx:wd@nixos-nuc.local:~/projects/github/2024/emacs/src")
        ("ubuntu2204" "~/github/2024/emacs/src")
        (_ "~/projects/github/2024/emacs/src")))

(use-package! find-func
  :custom
  (find-function-C-source-directory source-directory))

;; Add for some tramp/vterm connection and LSP json-rpc sessions.
(setq envrc-remote 1)

(after! tramp
  (setq tramp-default-method "ssh"
        remote-file-name-inhibit-cache 30)
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path)
  (dolist (p '("~/.nix-profile/bin" "/etc/profiles/per-user/wd/bin"))
    (add-to-list 'tramp-remote-path p))
  ;; tramp-gvfs 是 Linux/GNOME 专用，在 macOS 上对远程路径做 file-notify
  ;; 时会调用 `gio monitor`，每个 watcher 开一个 SSH 连接，导致连接爆炸。
  ;; 必须在加载前设置，阻止 tramp-gvfs 注册 ssh method 的 file-notify handler。
  (setq tramp-gvfs-methods nil)
  (defvar tramp-gvfs-enabled nil)
  (provide 'tramp-gvfs))

(after! lsp-mode
  (defvar +wd/remote-python-lsp-disabled-clients
    '(pyright pyright-tramp
      ruff ruff-tramp
      pylsp pylsp-tramp
      pyls pyls-tramp
      semgrep-ls semgrep-ls-tramp
      ty-ls ty-ls-tramp)
    "Clients disabled for remote Python buffers to keep a single LSP path.")

  (defun +wd/guard-remote-python-lsp ()
    "Reduce remote Python LSP overhead and avoid conflicting clients."
    (when (file-remote-p default-directory)
      (setq-local lsp-enable-file-watchers nil)
      (dolist (client +wd/remote-python-lsp-disabled-clients)
        (cl-pushnew client lsp-disabled-clients))))

  (dolist (hook '(python-mode-hook python-ts-mode-hook))
    (add-hook hook #'+wd/guard-remote-python-lsp)))

(after! lsp-pyright
  (setopt lsp-pyright-diagnostic-mode "openFilesOnly"
          lsp-pyright-multi-root nil)

  (defun +wd/pyright-remote-root ()
    "Return workspace root for remote pyright checks."
    (or (ignore-errors (lsp-workspace-root))
        default-directory))

  (defun +wd/pyright-remote-bin ()
    "Return remote pyright-langserver path, prefer PATH before .venv."
    (let* ((remote-root (+wd/pyright-remote-root))
           (default-directory remote-root)
           (from-path (executable-find "pyright-langserver" t))
           (from-venv (expand-file-name ".venv/bin/pyright-langserver" remote-root)))
      (cond
       ((and from-path (file-executable-p from-path)) from-path)
       ((file-executable-p from-venv) from-venv)
       (t nil)))))

(after! so-long
  (add-to-list 'doom-file-lines-threshold-alist
               '("\\.org\\'" . 50000)))

(provide 'init-core-runtime)
;;; init-core-runtime.el ends here
