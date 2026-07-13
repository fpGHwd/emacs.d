;;; lib-rime.el --- Rime IME helpers -*- lexical-binding: t; -*-

(defvar my/rime-compile-fallback-commands
  '("/home/wd/.config/dotfiles/local/scripts/2026/build-rime-module.sh"
    "make lib" "make" "make -C build" "cmake --build build")
  "如果 `rime-compile-module' 失败时按顺序尝试的备选编译命令（在 rime--root 目录执行）。")

(defun +my/rime-compile-module-advice (orig-fun &rest _)
  "Around advice：先调用 ORIG-FUN，出错时按 `my/rime-compile-fallback-commands' 依次尝试编译。"
  (condition-case err
      (funcall orig-fun)
    (error
     (let ((default-directory (file-name-as-directory rime--root)))
       (cl-dolist (cmd my/rime-compile-fallback-commands)
         (when (zerop (shell-command cmd))
           (cl-return)))
       (error "All rime compile attempts failed")))))

(defun +wd/rime-predicate-not-in-insert-p ()
  "Return t when meow is not in insert state.
Used as a rime-disable-predicate so rime only produces candidates in insert mode.
Minibuffer and terminal modes are exempted — text input there is always expected."
  (and (not meow-insert-mode)
       (not (minibufferp))
       (not (derived-mode-p 'vterm-mode 'comint-mode 'eat-mode))))

(defun +wd/rime-debug-enable ()
  "Manually enable rime-emacs for debugging."
  (interactive)
  (if (fboundp 'rime-force-enable)
      (call-interactively #'rime-force-enable)
    (user-error "rime is not loaded")))

(defun +pyim-probe-telega-msg ()
  "Return if current point is at a telega button."
  (s-contains? "telega" (symbol-name (get-text-property (point)
                                                        'category))))

(defun +wd/sync-emacs-rime-dict ()
  "Sync EMACS rime dictionary to git repository with default remote."
  (interactive)
  (let* ((rime-dir "~/.config/rime")
         (tmp-dir (concat rime-dir "/sync/tmp"))
         (tmp-file (concat tmp-dir "/rime_ice.userdb.txt"))
         (dict-file-relative "sync/rime-emacs/rime_ice.userdb.txt")
         (dict-file (concat rime-dir "/" dict-file-relative))
         (default-directory rime-dir)
         (commit-message (concat "update by elisp on " (format-time-string "%Y/%m/%d %H:%M:%S")))
         (upstream (magit-get-upstream-branch)))
    (mkdir tmp-dir t)
    (copy-file dict-file tmp-file t)
    (require 'magit)
    (magit-fetch-all-prune)           ; error handle
    (magit-reset-hard upstream)
    (rime-sync)
    (magit-stage-file dict-file-relative)
    (magit-commit-create `("--all" "-m" ,commit-message))
    (magit-push-current-to-upstream nil)))

(provide 'lib-rime)
;;; lib-rime.el ends here
