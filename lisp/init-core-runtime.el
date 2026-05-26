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

(setq source-directory "/sshx:wd@nixos-nuc:~/projects/github/2024/emacs/src")

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
    (add-to-list 'tramp-remote-path p)))

(after! lsp-mode
  ;; Auto-generated *-tramp clients use lsp-stdio-connection (interactive
  ;; shell → PTY), which corrupts JSON-RPC framing over TRAMP and causes
  ;; broken-pipe crashes. Only affects remote clients; local LSP unaffected.
  ;; lsp-pyright manually registers pyright-remote (lsp-tramp-connection,
  ;; pure pipe), which is the only correct remote client we need.
  (setopt lsp-auto-register-remote-clients nil)

  ;; File watchers on remote TRAMP paths open one SSH connection per watched
  ;; directory (28+ for a typical pyright workspace), causing a connection
  ;; explosion that crashes Emacs. Intercept capability registration and
  ;; skip watcher setup when the workspace root is remote.
  (advice-add 'lsp--server-register-capability :around
    (lambda (orig reg)
      (if (and (equal (plist-get reg :method) "workspace/didChangeWatchedFiles")
               (when-let ((root (lsp-workspace-root)))
                 (file-remote-p root)))
          (lsp-log "Skipping file watcher registration for remote workspace")
        (funcall orig reg)))
    '((name . +wd/skip-watchers-for-remote-workspace))))

(after! so-long
  (add-to-list 'doom-file-lines-threshold-alist
               '("\\.org\\'" . 50000)))

(provide 'init-core-runtime)
;;; init-core-runtime.el ends here
