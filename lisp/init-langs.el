;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

(setup eglot
  (:option eglot-max-file-watches 524288))

(after! treesit
  (setf (alist-get 'go treesit-language-source-alist)
        '("https://github.com/tree-sitter/tree-sitter-go" "v0.23.4" nil nil nil nil)))

(setup sql
  (:option sql-mysql-program "mariadb"))

;; ARXML breadcrumb: show ancestor path of XML element at point in header-line
(define-minor-mode arxml-breadcrumb-mode
  "Toggle ARXML breadcrumb display in header-line."
  :init-value nil
  :lighter " Breadcrumb"
  (if arxml-breadcrumb-mode
      (add-hook 'post-command-hook #'+wd/arxml-breadcrumb-update nil t)
    (remove-hook 'post-command-hook #'+wd/arxml-breadcrumb-update t)
    (setq header-line-format nil)))

(setup nxml-mode
  (:also-load lib-arxml)
  (:hook (lambda ()
           (when (string-suffix-p ".arxml" (or buffer-file-name ""))
             (arxml-breadcrumb-mode 1))))
  (:with-map nxml-mode-map
    (:bind "C-c b" #'+wd/arxml-breadcrumb-jump-to-ancestor)))

(provide 'init-langs)
;;; init-langs.el ends here
