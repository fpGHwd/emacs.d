;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

;; flycheck's emacs-lisp checker spawns a bare emacs process without Doom macros loaded,
;; producing false "free variable" warnings for config files. Just it out.
(add-hook! 'emacs-lisp-mode-hook (flycheck-mode -1))

(setup eglot
  (:option eglot-max-file-watches 524288))

(after! treesit
  (setf (alist-get 'go treesit-language-source-alist)
        '("https://github.com/tree-sitter/tree-sitter-go" "v0.23.4" nil nil nil nil))
  (setf (alist-get 'xml treesit-language-source-alist)
        '("https://github.com/tree-sitter/tree-sitter-xml" nil "grammars/xml/src" nil nil nil)))

(setup sql
  (:option sql-mysql-program "mariadb"))

;; ARXML breadcrumb: show ancestor path of XML element at point in header-line
(define-minor-mode arxml-breadcrumb-mode
  "Toggle ARXML breadcrumb display in header-line."
  :init-value nil
  :lighter " Breadcrumb"
  (if arxml-breadcrumb-mode
      (progn
        (add-hook 'post-command-hook #'+wd/arxml-breadcrumb-schedule nil t)
        (add-hook 'after-change-functions #'+wd/arxml-breadcrumb-invalidate-cache nil t))
    (remove-hook 'post-command-hook #'+wd/arxml-breadcrumb-schedule t)
    (remove-hook 'after-change-functions #'+wd/arxml-breadcrumb-invalidate-cache t)
    (when +wd/arxml--breadcrumb-timer
      (cancel-timer +wd/arxml--breadcrumb-timer))
    (setq +wd/arxml--breadcrumb-timer nil
          +wd/arxml--breadcrumb-cache nil)
    (setq header-line-format nil)))

(setup nxml-mode
  (:also-load lib-arxml)
  (:hook (lambda ()
           (when (string-suffix-p ".arxml" (or buffer-file-name ""))
             (arxml-breadcrumb-mode 1))))
  (:with-map nxml-mode-map
    (:bind "C-c c f" #'+wd/arxml-breadcrumb-jump-to-ancestor)))

(provide 'init-langs)
;;; init-langs.el ends here
