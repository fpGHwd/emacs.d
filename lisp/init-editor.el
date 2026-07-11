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
     blink-cursor-interval 0.618
     meow-cursor-type-normal 'box
     meow-cursor-type-motion 'box
     meow-cursor-type-beacon 'box
     meow-cursor-type-insert 'bar)
    (advice-add 'meow-cheatsheet :after
                (lambda (&rest _)
                  (when-let ((buf (get-buffer "*Meow Cheatsheet*")))
                    (with-current-buffer buf
                      (buffer-face-set :family "Sarasa Fixed SC")
                      (meow-normal-mode -1)
                      (local-set-key "q" #'quit-window)))))))

(provide 'init-editor)
;;; init-editor.el ends here
