;;; init-lookup.el --- Search and dictionary configuration -*- lexical-binding: t; -*-

(setup doom
  (:with-map doom-leader-map
    (:bind
     "z" (cons "Wang Ding defining" (make-sparse-keymap))
     "z r" (cons "Reading via Calibre" #'calibredb)
     "z B" (cons "Write a new blog" #'blog-post)
     "z Q" (cons "Search org by tags" #'+wd/org-search-by-tags))))

(provide 'init-lookup)
;;; init-lookup.el ends here
