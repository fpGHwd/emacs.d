;;; init-lsp.el --- Cross-language LSP configuration -*- lexical-binding: t; -*-

(setup lsp-haskell
  (:when-loaded
    (:option lsp-haskell-formatting-provider "brittany")))

(setup lsp-mode
  (:when-loaded
    ;; Auto-generated *-tramp clients use lsp-stdio-connection (interactive
    ;; shell → PTY), which corrupts JSON-RPC framing over TRAMP and causes
    ;; broken-pipe crashes. Only affects remote clients; local LSP unaffected.
    ;; lsp-pyright manually registers pyright-remote (lsp-tramp-connection,
    ;; pure pipe), which is the only correct remote client we need.
    (:option lsp-auto-register-remote-clients nil)

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
      '((name . +wd/skip-watchers-for-remote-workspace)))))

(provide 'init-lsp)
;;; init-lsp.el ends here
