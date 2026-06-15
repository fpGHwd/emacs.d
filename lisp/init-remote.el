;;; init-remote.el --- TRAMP and remote source/env configuration -*- lexical-binding: t; -*-

(setup find-func
  (:option find-function-C-source-directory "/sshx:wd@nixos-nuc:~/projects/github/2024/emacs/src")

(setup envrc
  (:option envrc-remote t))

(setup tramp
  (:when-loaded
    (add-to-list 'tramp-remote-path "/home/wd/.nix-profile/bin")))

(setup tramp-sh
  (:when-loaded
    (setq tramp-default-remote-shell "zsh")))

(provide 'init-remote)
;;; init-remote.el ends here
