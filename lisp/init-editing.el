;;; init-editing.el --- Editing configuration -*- lexical-binding: t; -*-

;; Cursor settings
(setq blink-cursor-interval 0.618)

;; Evil-specific overrides (if needed)
;; (after! evil
;;   ...)


(after! meow
  (meow-normal-define-key '("<return>" . meow-line))
  (add-hook 'git-commit-mode-hook #'meow-insert)
  (add-hook 'vterm-mode-hook #'meow-insert)
  (setq meow-cursor-type-normal 'box
        meow-cursor-type-motion 'box
        meow-cursor-type-beacon 'box
        meow-cursor-type-insert 'bar))

(provide 'init-editing)
;;; init-editing.el ends here
