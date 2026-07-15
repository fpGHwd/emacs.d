;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

(setup eglot
  (:option eglot-max-file-watches 524288))

(after! treesit
  (setf (alist-get 'go treesit-language-source-alist)
        '("https://github.com/tree-sitter/tree-sitter-go" "v0.23.4" nil nil nil)))

(setup sql
  (:option sql-mysql-program "mariadb"))

(provide 'init-langs)
;;; init-langs.el ends here
