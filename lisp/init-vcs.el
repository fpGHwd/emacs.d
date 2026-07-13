;;; init-vcs.el --- Version control (Magit) configuration -*- lexical-binding: t; -*-

(setup magit-clone
  (:option magit-clone-default-directory (concat (file-truename "~/projects/github/current") "/")))

(setup magit
  (:also-load lib-git)
  (:when-loaded
   (with-eval-after-load 'meow
     ;; git-commit-mode is a minor mode, meow matches on major mode (text-mode).
     ;; Use git-commit-setup-hook to switch to insert state instead.
     (add-hook 'git-commit-setup-hook #'meow-insert-mode))))

(provide 'init-vcs)
;;; init-vcs.el ends here
