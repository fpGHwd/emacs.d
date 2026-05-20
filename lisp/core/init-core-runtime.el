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

;; LSP over TRAMP (ssh://nixos-nuc): prefer remote-resolvable JSON LS commands.
(after! tramp
  (add-to-list 'tramp-remote-path 'tramp-own-remote-path)
  (dolist (p '("~/.nix-profile/bin" "/etc/profiles/per-user/wd/bin" "/run/current-system/sw/bin"))
    (add-to-list 'tramp-remote-path p)))

(after! lsp-mode
  (defvar +wd/json-ls-remote-candidates
    '("json-language-server"
      "json-languageserver"
      "vscode-json-language-server"
      "vscode-json-languageserver")
    "Candidate executables for JSON language server on remote hosts.")

  (defun +wd/tramp-json-ls-executable ()
    "Return remote JSON language server executable, or nil if unavailable."
    (when (file-remote-p default-directory)
      (cl-loop for exe in +wd/json-ls-remote-candidates
               when (eq 0 (process-file "sh" nil nil nil "-lc"
                                        (format "command -v %s >/dev/null 2>&1" exe)))
               return exe)))

  (defun +wd/maybe-disable-json-ls-on-tramp ()
    "Disable json-ls in remote JSON buffers when no server command exists."
    (when (and (file-remote-p default-directory)
               (null (+wd/tramp-json-ls-executable)))
      (setq-local lsp-disabled-clients
                  (cl-adjoin 'json-ls lsp-disabled-clients :test #'eq))
      (message "Remote json-ls disabled: install vscode-json-language-server on remote host.")))

  (defun +wd/lsp-json-use-remote-command-a (orig-fn pkg)
    "Advice ORIG-FN to return remote JSON LS command for PKG over TRAMP."
    (if (and (eq pkg 'vscode-json-languageserver)
             (file-remote-p default-directory))
        (or (+wd/tramp-json-ls-executable) (funcall orig-fn pkg))
      (funcall orig-fn pkg)))

  (advice-add 'lsp-package-path :around #'+wd/lsp-json-use-remote-command-a)
  ;; Doom with +tree-sitter uses `json-ts-mode`, so guard both mode hooks.
  (add-hook 'json-mode-hook #'+wd/maybe-disable-json-ls-on-tramp)
  (add-hook 'json-ts-mode-hook #'+wd/maybe-disable-json-ls-on-tramp))

(after! so-long
  (add-to-list 'doom-file-lines-threshold-alist
               '("\\.org\\'" . 50000)))

(provide 'init-core-runtime)
;;; init-core-runtime.el ends here
