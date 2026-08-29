;;; init-remote.el --- TRAMP and remote source/env configuration -*- lexical-binding: t; -*-

(setup envrc
  (:setopt envrc-remote t))

(setup tramp
  (:setopt
   tramp-default-method "sshx"
   tramp-default-remote-shell "zsh")
  (:when-loaded
    (:setopt (prepend tramp-remote-path) "/home/wd/.nix-profile/bin")))

(provide 'init-remote)
;;; init-remote.el ends here
