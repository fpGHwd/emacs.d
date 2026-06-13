;;; init-vcs.el --- Version control (Magit) configuration -*- lexical-binding: t; -*-

(setup magit-clone
  (:when-loaded
    (:option magit-clone-default-directory (concat (file-truename "~/projects/github/current") "/"))))

(setup magit
  (:also-load lib-git)
  (:hooks git-commit-mode-hook meow-insert))

(provide 'init-vcs)
;;; init-vcs.el ends here
