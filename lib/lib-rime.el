;;; lib-rime.el --- Rime IME helpers -*- lexical-binding: t; -*-


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
