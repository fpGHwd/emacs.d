;;; init-ebooks.el --- EPUB and ebook mode configuration -*- lexical-binding: t; -*-

;; https://emacs-china.org/t/emacs-epub/4713/11
;; FIXME: errors while opening `nov' files with Unicode characters
(with-no-warnings
  (defun my-nov-content-unique-identifier (content)
    "Return the the unique identifier for CONTENT."
    (when-let* ((name (nov-content-unique-identifier-name content))
                (selector (format "package>metadata>identifier[id='%s']"
                                  (regexp-quote name)))
                (id (car (esxml-node-children (esxml-query selector content)))))
      (intern id))))

(setup nov
  (:match-file "*.epub")
  (:advice nov-content-unique-identifier :override #'my-nov-content-unique-identifier))

(provide 'init-ebooks)
;;; init-ebooks.el ends here
