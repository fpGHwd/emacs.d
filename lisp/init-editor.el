;;; init-editor.el --- Modal editing (meow), lispy, and clipboard -*- lexical-binding: t; -*-

(setup meow
  (:when-loaded
    (meow-normal-define-key '("RET" . ignore))
    (meow-normal-define-key '("<return>" . ignore))
    (meow-normal-define-key '("DEL" . ignore))
    (meow-normal-define-key '("<backspace>" . ignore))
    (meow-normal-define-key '("C-o" . better-jumper-jump-backward))
    (meow-normal-define-key '("%" . lispy-different))
    (meow-normal-define-key '("=" . indent-region))
    (:option
     meow-cursor-type-normal 'box
     meow-cursor-type-motion 'box
     meow-cursor-type-beacon 'box
     meow-cursor-type-insert 'bar
     blink-cursor-interval 0.618)
    (advice-add 'meow-cheatsheet :after
                (lambda (&rest _)
                  (when-let ((buf (get-buffer "*Meow Cheatsheet*")))
                    (with-current-buffer buf
                      (buffer-face-set :family "Sarasa Fixed SC")
                      (meow-motion-overwrite-define-key '("q" . quit-window))))))))

;; Doom module :config re-executes on doom/reload, overriding the :option values
;; above. Re-apply after reload to ensure our cursor types win.
(add-hook! 'doom-after-reload-hook
  (setq meow-cursor-type-normal 'box
        meow-cursor-type-motion 'box
        meow-cursor-type-beacon 'box
        meow-cursor-type-insert 'bar
        blink-cursor-interval 0.618))

(provide 'init-editor)
;;; init-editor.el ends here
