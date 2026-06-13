;;; init-vcs.el --- Version control (Magit) configuration -*- lexical-binding: t; -*-

(use-package! magit-clone
  :defer t
  :custom
  (magit-clone-default-directory (concat (file-truename "~/projects/github/current") "/")))

(setup magit
  (:also-load lib-git))

(add-hook 'git-commit-mode-hook #'meow-insert)

(provide 'init-vcs)
;;; init-vcs.el ends here
