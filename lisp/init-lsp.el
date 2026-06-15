;;; init-lsp.el --- Cross-language LSP (eglot) configuration -*- lexical-binding: t; -*-

(setup eglot
  (:when-loaded
    ;; eglot only disables file watching for remote (trampish) projects; for
    ;; local ones it advertises didChangeWatchedFiles with dynamicRegistration.
    ;; Servers like pyright then request watches covering the whole nix python
    ;; env (site-packages/typeshed, tens of thousands of files), blowing past
    ;; eglot-max-file-watches (10000). Registering that many inotify watches
    ;; stalls the single-threaded main loop and triggers an endless
    ;; server-exit/reconnect storm that freezes Emacs. Skip watcher
    ;; registration entirely — servers work fine without push-based watches
    ;; (in-buffer edits still sync via didChange).
    (advice-add 'eglot-register-capability :around
                (lambda (orig server method id &rest params)
                  (unless (eq method 'workspace/didChangeWatchedFiles)
                    (apply orig server method id params)))
                '((name . +wd/eglot-skip-file-watchers)))))

(provide 'init-lsp)
;;; init-lsp.el ends here
