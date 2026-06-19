;;; init-remote.el --- TRAMP and remote source/env configuration -*- lexical-binding: t; -*-

(setup envrc
  (:option envrc-remote t))

(setup tramp
  (:when-loaded
    (setq tramp-default-remote-shell "zsh")
    (add-to-list 'tramp-remote-path "/home/wd/.nix-profile/bin")))

(provide 'init-remote)
;;; init-remote.el ends here
