;;; init-tramp.el --- TRAMP and remote LSP configuration -*- lexical-binding: t; -*-

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

(provide 'init-tramp)
;;; init-tramp.el ends here
