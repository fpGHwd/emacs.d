;;; init-remote.el --- TRAMP and remote source/env configuration -*- lexical-binding: t; -*-

(setup envrc
  (:option envrc-remote t))

(setup tramp
  (:option
   tramp-default-method "sshx"
   tramp-default-remote-shell "zsh")
  (:when-loaded
    (add-to-list 'tramp-remote-path "/home/wd/.nix-profile/bin")))

(provide 'init-remote)
;;; init-remote.el ends here
