;;; init-ebooks.el --- EPUB and ebook mode configuration -*- lexical-binding: t; -*-

(setup nov
  (:match-file "*.epub")
  (:advice nov-content-unique-identifier :override #'my-nov-content-unique-identifier))

(provide 'init-ebooks)
;;; init-ebooks.el ends here
