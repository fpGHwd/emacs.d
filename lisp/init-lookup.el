;;; init-lookup.el --- Search and dictionary configuration -*- lexical-binding: t; -*-

(setup doom
  (:when-loaded
    (map! :leader
          (:prefix ("z" . "Wang Ding defining"))
          :desc "Reading via Calibre" "r" #'calibredb)
    (when (string= (system-name) "ubuntu2204")
      (add-to-list '+lookup-provider-url-alist
                   '("Bing" "https://cn.bing.com/search?go=Search&q=%s&qs=ds&form=QBRE")))
    (add-to-list '+lookup-provider-url-alist
                 '("NixOS Package Search" "https://search.nixos.org/packages?channel=25.11&query=%s"))))

(provide 'init-lookup)
;;; init-lookup.el ends here
