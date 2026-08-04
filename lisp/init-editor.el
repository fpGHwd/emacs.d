;;; init-editor.el --- Modal editing (meow), lispy, and clipboard -*- lexical-binding: t; -*-

(when (eq system-type 'gnu/linux)
  (setup (:require xclip)
    (:option xclip-method 'wl-copy
             xclip-program "wl-copy")
    (:when-loaded
      (setq interprogram-cut-function
            (apply-partially #'xclip-set-selection 'CLIPBOARD)
            interprogram-paste-function
            (apply-partially #'xclip-get-selection 'CLIPBOARD)))))

(setup meow
  (:also-load lib-util)
  (:hooks doom-after-reload-hook (lambda ()
            (setq meow-cursor-type-normal 'box
                  meow-cursor-type-motion 'box
                  meow-cursor-type-beacon 'box
                  meow-cursor-type-insert 'bar
                  blink-cursor-interval 0.618)))
  (:when-loaded
    (meow-normal-define-key
     '("RET" . +wd/meow-normal-return)
     '("DEL" . ignore)
     '("C-o" . better-jumper-jump-backward)
     '("=" . indent-region)
     '("q" . quit-window))
    (add-hook! 'prog-mode-hook
      (meow-normal-define-key '("%" . lispy-different)))
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
                      (buffer-face-set :family "Sarasa Fixed SC")))))))

(provide 'init-editor)
;;; init-editor.el ends here
