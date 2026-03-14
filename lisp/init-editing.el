;;; ../../Sync/dotfiles/doom.d/lisp/init-editing.el -*- lexical-binding: t; -*-

(setup meow
  (:also-load lib-meow)
  (:with-function meow-setup (:autoload-this))
  (meow-global-mode 1)
  (meow-setup)
  (:option  wrap-keymap (let ((map (make-keymap)))
                          (suppress-keymap map)
                          (dolist (k '("(" "[" "{" "<"))
                            (define-key map k #'insert-pair))
                          map))
  (meow-normal-define-key (cons "\\" wrap-keymap))
  (:hooks meow-insert-mode-hook
          (lambda ()
            (if meow-insert-mode
                (run-hooks 'meow-entering-insert-mode-hook)
              (run-hooks 'meow-leaving-insert-mode-hook))))
  (when *is-mac*
    (:advice meow-mark-thing :override meow-mark-thing-cjk)
    (:advice meow-next-thing :override meow-next-thing-cjk)))

(setup meow-tree-sitter
  (:defer (:require meow-tree-sitter))
  (:when-loaded (meow-tree-sitter-register-defaults)))

(setup sis
  (:defer (:require sis))
  (:when-loaded
    (:option sis-english-source "com.apple.keylayout.ABC"
             ;; 用了 emacs-mac 提取的 patch 中的 mac-input-source 方法来切换
             ;; sis-external-ism "macism"
             sis-inline-tighten-head-rule nil
             sis-default-cursor-color "#cf7fa7"
             sis-other-cursor-color "orange"
             sis-context-hooks '(meow-insert-enter-hook))
    (:hooks meow-insert-exit-hook sis-set-english
            meow-motion-mode-hook sis-set-english)
    (if *is-mac*
        (sis-ism-lazyman-config
         "com.apple.keylayout.ABC"
         "im.rime.inputmethod.Squirrel.Hans")
      (sis-ism-lazyman-config "1" "2" 'fcitx5))
    ;; enable the /cursor color/ mode
    (sis-global-cursor-color-mode t)
    ;; enable the /respect/ mode
    (sis-global-respect-mode t)
    ;; enable the /context/ mode for all buffers
    (sis-global-context-mode t)
    ;; enable the /inline english/ mode for all buffers
    ;; (sis-global-inline-mode t)
    ;; org title 处切换 Rime，telega 聊天时切换 Rime。
    ;; 使用模式编辑 meow，需要额外加 meow-insert-mode 条件。
    (add-to-list 'sis-context-detectors
                 (lambda (&rest _)
                   (when (and meow-insert-mode
                              (or (derived-mode-p 'org-mode
                                                  'gfm-mode
                                                  'telega-chat-mode)
                                  (string-match-p "*new toot*" (buffer-name))))
                     'other)))

    (add-function :after after-focus-change-function
                  (lambda ()
                    (if (frame-focus-state)
                        (sis-set-english)
                      (meow-insert-exit))))

    (define-advice sis--auto-refresh-timer-function
        (:around (orig) toggle-override-map)
      (funcall orig)
      (pcase sis--current
        ('english
         (setq sis--prefix-override-map-enable nil))
        ('other
         (setq sis--prefix-override-map-enable t))))))


(provide 'init-editing)
