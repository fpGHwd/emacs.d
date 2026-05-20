;;; ../../Sync/dotfiles/doom.d/lisp/init-editing.el -*- lexical-binding: t; -*-

(defun +wd/meow-run-insert-mode-hooks ()
  "Bridge Meow insert toggles to custom entering/leaving hooks."
  (if meow-insert-mode
      (run-hooks 'meow-entering-insert-mode-hook)
    (run-hooks 'meow-leaving-insert-mode-hook)))

;; Keep Meow cheatsheet alignment stable: fixed pitch + no soft wrap.
(defun +wd/meow-cheatsheet-display-fix (&rest _)
  "Normalize the *Meow Cheatsheet* buffer display."
  (when-let ((buf (get-buffer "*Meow Cheatsheet*")))
    (with-current-buffer buf
      (setq-local truncate-lines t)
      (setq-local word-wrap nil)
      (setq-local line-spacing 0)
      (buffer-face-set 'fixed-pitch)
      (text-scale-set 0))))

(after! meow
  ;; Keep doom-meow as the source of truth for base keymaps/state machine.
  ;; We only layer local overrides here.
  (require 'lib-meow)

  (let ((wrap-keymap (let ((map (make-keymap)))
                       (suppress-keymap map)
                       (dolist (k '("(" "[" "{" "<"))
                         (define-key map k #'insert-pair))
                       map)))
    (meow-normal-define-key (cons "\\" wrap-keymap)))

  ;; TODO/IMPLEMENT: Enter insert state automatically in Magit commit message buffers.

  (remove-hook 'meow-insert-mode-hook #'+wd/meow-run-insert-mode-hooks)
  (add-hook 'meow-insert-mode-hook #'+wd/meow-run-insert-mode-hooks)

  (unless (advice-member-p #'+wd/meow-cheatsheet-display-fix 'meow-cheatsheet)
    (advice-add 'meow-cheatsheet :after #'+wd/meow-cheatsheet-display-fix))

  (when *is-mac*
    (unless (advice-member-p #'meow-mark-thing-cjk 'meow-mark-thing)
      (advice-add 'meow-mark-thing :override #'meow-mark-thing-cjk))
    (unless (advice-member-p #'meow-next-thing-cjk 'meow-next-thing)
      (advice-add 'meow-next-thing :override #'meow-next-thing-cjk)))

  (setq meow-cheatsheet-ellipsis "…")
  (set-face-attribute 'meow-cheatsheet-command nil
                      :inherit 'fixed-pitch
                      :height 1.0)
  (set-face-attribute 'meow-cheatsheet-highlight nil :inherit 'meow-cheatsheet-command))

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

(setq blink-cursor-interval 0.618)
(setq meow-cursor-type-normal 'box)

;; https://github.com/meow-edit/meow/blob/master/TUTORIAL.org
;; https://github.com/meow-edit/meow/blob/master/GET_STARTED.org
;; https://github.com/meow-edit/doom-meow
;; https://chatgpt.com/c/6a0dc321-0dac-83a3-a63f-8f6da6ce5552

;; TODO: 增加模式设置，以及某些状态下快捷键的设置：例如 normal backspace 不要，motion j/k 是上下。magit 进入 motion 等

(provide 'init-editing)
