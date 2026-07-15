;;; lib-util.el --- General utilities -*- lexical-binding: t; -*-


(defun surround-quotes (&optional arg)
  "Enclose following ARG sexps in quotes.
Leave point after open-quote."
  (interactive "*P")
  (insert-pair arg ?\" ?\"))


;; open vscode in current line
(defun +wd/open-with-vscode ()
  "Open current file with vscode."
  (interactive)
  (let ((line (number-to-string (line-number-at-pos)))
        (column (number-to-string (current-column))))
    (apply 'call-process "code" nil nil nil (list (concat buffer-file-name ":" line ":" column) "--goto"))))


(defun +wd/meow-normal-return ()
  (interactive)
  (cond
   ((derived-mode-p 'org-mode) (call-interactively #'+org/dwim-at-point))
   (t (ignore))))

(provide 'lib-util)
;;; lib-util.el ends here
