;;; init-tramp.el --- TRAMP and remote source/env configuration -*- lexical-binding: t; -*-

(setq source-directory "/sshx:wd@nixos-nuc:~/projects/github/2024/emacs/src")

(setup find-func
  (:option find-function-C-source-directory source-directory))

;; Add for some tramp/vterm connection and LSP json-rpc sessions.
(setq envrc-remote 1)

(setup tramp
  (:when-loaded
    (setq tramp-default-method "ssh"
          remote-file-name-inhibit-cache 30)
    (add-to-list 'tramp-remote-path 'tramp-own-remote-path)
    (dolist (p '("~/.nix-profile/bin" "/etc/profiles/per-user/wd/bin"))
      (add-to-list 'tramp-remote-path p))))

(provide 'init-tramp)
;;; init-tramp.el ends here
