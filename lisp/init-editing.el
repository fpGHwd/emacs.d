;;; init-editing.el --- Editing configuration -*- lexical-binding: t; -*-

;; Cursor settings
(setq blink-cursor-interval 0.618)

;; Evil-specific overrides (if needed)
;; (after! evil
;;   ...)


(after! meow
  (meow-normal-define-key '("<return>" . meow-line))
  (add-hook 'git-commit-mode-hook #'meow-insert))

(provide 'init-editing)
;;; init-editing.el ends here
