;;; init-vcs.el --- Version control (Magit) configuration -*- lexical-binding: t; -*-

(setup magit-clone
  (:when-loaded
    (:option magit-clone-default-directory (concat (file-truename "~/projects/github/current") "/"))))

(setup magit
  (:also-load lib-git)
  (:when-loaded
   (with-eval-after-load 'meow
     (add-to-list 'meow-mode-state-list '(git-commit-mode . motion)))))

(provide 'init-vcs)
;;; init-vcs.el ends here
