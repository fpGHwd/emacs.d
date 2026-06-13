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
        meow-cursor-type-insert 'bar)
  ;; Box-drawing chars in the cheatsheet fall back to Sarasa Fixed SC; force
  ;; the whole buffer to use it so ASCII and box chars share the same metrics.
  (advice-add 'meow-cheatsheet :after
              (lambda (&rest _)
                (when-let ((buf (get-buffer "*Meow Cheatsheet*")))
                  (with-current-buffer buf
                    (when (member "Sarasa Fixed SC" (font-family-list))
                      (buffer-face-set
                       `(:family "Sarasa Fixed SC"))))))))

(provide 'init-editing)
;;; init-editing.el ends here
