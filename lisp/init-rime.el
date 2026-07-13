;;; init-rime.el --- Input method (Rime) -*- lexical-binding: t; -*-

(setq default-input-method "rime")

(setup rime
  (:bind "M-\\" rime-force-enable)
  (:when-loaded
    (:also-load lib-rime)
    (:option
     rime-posframe-properties (list :background-color "#666699"
                                    :foreground-color "#dcdccc"
                                    :font (format "Sarasa Gothic SC-%d" (1+ (font-get doom-font :size))))
     ;; rime-show-candidate 'minibuffer
     rime-show-candidate 'posframe
     rime-disable-predicates '(rime-predicate-auto-english-p
                               ;; rime-predicate-space-after-cc-p
                               rime-predicate-current-uppercase-letter-p
                               +pyim-probe-telega-msg
                               +wd/rime-predicate-not-in-insert-p)
     rime-inline-ascii-trigger 'shift-l
     ;;  set LIBRIME_ROOT and EMACS_MODULE_HEADER_ROOT in emacs.nix already
     rime-emacs-module-header-root (concat (getenv "LIBEMACS_ROOT") "/include")
     rime-librime-root (getenv "LIBRIME_ROOT")
     module-file-suffix (getenv "MODULE_FILE_SUFFIX")
     rime-user-data-dir (file-truename "~/.config/rime"))
    ;; Input method follows editing state: deactivate rime when leaving insert mode
    (add-hook 'meow-insert-exit-hook #'deactivate-input-method))

  ;; 安装 advice（在 rime 被载入后执行，函数定义在 lib-rime）
  (advice-add 'rime-compile-module :around #'+my/rime-compile-module-advice))

(provide 'init-rime)
;;; init-rime.el ends here
