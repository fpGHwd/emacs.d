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

;; Under pgtk on Wayland, Emacs keeps believing it owns CLIPBOARD when it loses
;; focus (Wayland only delivers selection-cancelled events to the focused
;; surface), so yank returns its own stale value. Route cut/paste through
;; wl-clipboard to bypass GTK selection ownership entirely.
;;
;; Only enable on a pgtk build with a real wl-clipboard backend present:
;; `xclip-mode' with no backend program (no xclip/xsel/wl-copy) leaves
;; cut/paste half-broken so yank can no longer reach the system CLIPBOARD.
;; On X11 the built-in `gui-selection-value' already reads CLIPBOARD, so
;; xclip is unnecessary there.
(setup xclip
  (:when-loaded
    (when (and (featurep 'pgtk)
               (executable-find "wl-paste")
               (executable-find "wl-copy"))
      (xclip-mode 1))))

(provide 'init-editor)
;;; init-editor.el ends here
