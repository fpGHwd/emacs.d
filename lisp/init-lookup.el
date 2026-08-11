;;; init-lookup.el --- Search and dictionary configuration -*- lexical-binding: t; -*-

(setup doom
  (:when-loaded
    (map! :leader
          (:prefix ("z" . "Wang Ding defining")
           :desc "Reading via Calibre" "r" #'calibredb))))

(provide 'init-lookup)
;;; init-lookup.el ends here
