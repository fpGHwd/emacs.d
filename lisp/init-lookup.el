;;; init-lookup.el --- Search and dictionary configuration -*- lexical-binding: t; -*-

(setup doom
  (:when-loaded
    (map! :leader
          (:prefix ("z" . "Wang Ding defining")
           :desc "Reading via Calibre" "r" #'calibredb
           :desc "Write a new blog"    "B" #'blog-post
           :desc "Search org by tags" "Q" #'+wd/org-search-by-tags))))

(provide 'init-lookup)
;;; init-lookup.el ends here
