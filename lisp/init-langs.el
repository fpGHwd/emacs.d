;;; init-langs.el --- Language modes without dedicated files -*- lexical-binding: t; -*-

(setup eglot
  (:option eglot-max-file-watches 524288))

(setup sql
  (:option sql-mysql-program "mariadb"))

(provide 'init-langs)
;;; init-langs.el ends here
