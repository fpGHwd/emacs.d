;;; ../Sync/dotfiles/doom.d/lisp/init-rime.el -*- lexical-binding: t; -*-

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
                               +pyim-probe-telega-msg)
     rime-inline-ascii-trigger 'shift-l
     ;;  set LIBRIME_ROOT and EMACS_MODULE_HEADER_ROOT in emacs.nix already
     rime-emacs-module-header-root (concat (getenv "LIBEMACS_ROOT") "/include")
     rime-librime-root (getenv "LIBRIME_ROOT")
     module-file-suffix (getenv "MODULE_FILE_SUFFIX")
     rime-user-data-dir (file-truename "~/.config/rime"))
    ;; (:after evil-mode
    ;;   (:global "M-\\" rime-force-enable))
    )

  (defvar my/rime-compile-fallback-commands
    '("/home/wd/.config/dotfiles/local/scripts/2026/build-rime-module.sh"
      "make lib" "make" "make -C build" "cmake --build build")
    "如果 `rime-compile-module' 失败时按顺序尝试的备选编译命令（在 rime--root 目录执行）。")

  (defun my/rime-compile-module-advice (orig-fun &rest args)
    "Around advice：先调用 ORIG-FUN，出错时按 `my/rime-compile-fallback-commands' 依次尝试编译。"
    (condition-case err
        (apply orig-fun args)
      (error
       (message "rime-compile-module failed: %S. Trying fallback commands..." err)
       (let* ((root (or (and (boundp 'rime--root) rime--root) default-directory))
              (result
               (catch 'success
                 (dolist (cmd my/rime-compile-fallback-commands)
                   (let ((default-directory (file-name-as-directory (expand-file-name root))))
                     (message "Running fallback: %s (in %s)" cmd default-directory)
                     (when (zerop (shell-command cmd))
                       (throw 'success cmd))))
                 nil)))
         (if result
             (message "Fallback compile succeeded with: %s" result)
           (error "All rime compile attempts failed"))))))

  ;; 安装 advice（在 rime 被载入后执行）
  (advice-add 'rime-compile-module :around #'my/rime-compile-module-advice))

(provide 'init-rime)
;;; init-rime.el ends here
