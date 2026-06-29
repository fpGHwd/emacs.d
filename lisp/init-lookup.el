;;; init-lookup.el --- Search and dictionary configuration -*- lexical-binding: t; -*-

(setup doom
  (:when-loaded
    (when (string= (system-name) "ubuntu2204")
      (add-to-list '+lookup-provider-url-alist
                   '("Bing" "https://cn.bing.com/search?go=Search&q=%s&qs=ds&form=QBRE")))
    (add-to-list '+lookup-provider-url-alist
                 '("NixOS Package Search" "https://search.nixos.org/packages?channel=25.11&query=%s"))))

;; (setup bing-dict
;;   (:hooks doom-first-file-hook (lambda () (require 'bing-dict)))
;;   (:when-loaded
;;     (:option bing-dict-vocabulary-save t
;;              bing-dict-vocabulary-file (concat doom-user-dir "/etc/bing-dict/vocabulary.org"))
;;     (map! :leader :desc "Search word via Bing Dictionary" "sy" #'bing-dict-brief)))

(setup eldoc
  (:option eldoc-idle-delay 2))

(provide 'init-lookup)
;;; init-lookup.el ends here
