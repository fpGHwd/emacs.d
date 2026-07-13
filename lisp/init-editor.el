;;; init-editor.el --- Modal editing (meow), lispy, and clipboard -*- lexical-binding: t; -*-

;; Override Doom's cursor defaults — these must run AFTER Doom's meow module
;; :config block (which sets them to 'bar).  Doom modules are re-evaluated on
;; `doom/reload', so top-level setq gets overridden.  Using
;; `doom-after-modules-config-hook' guarantees our values win.
(add-hook! 'doom-after-modules-config-hook
  (setq meow-cursor-type-normal 'box
        meow-cursor-type-motion 'box
        meow-cursor-type-beacon 'box
        meow-cursor-type-insert 'bar
        blink-cursor-interval 0.618))

(setup meow
  (:when-loaded
    (meow-normal-define-key '("RET" . ignore))
    (meow-normal-define-key '("<return>" . ignore))
    (meow-normal-define-key '("DEL" . ignore))
    (meow-normal-define-key '("<backspace>" . ignore))
    (meow-normal-define-key '("C-o" . better-jumper-jump-backward))
    (meow-normal-define-key '("%" . lispy-different))
    (meow-normal-define-key '("=" . indent-region))
    (advice-add 'meow-cheatsheet :after
                (lambda (&rest _)
                  (when-let ((buf (get-buffer "*Meow Cheatsheet*")))
                    (with-current-buffer buf
                      (buffer-face-set :family "Sarasa Fixed SC")
                      (meow-normal-mode -1)
                      (local-set-key "q" #'quit-window)))))))

(provide 'init-editor)
;;; init-editor.el ends here
