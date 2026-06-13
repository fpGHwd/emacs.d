;;; init-lookup.el --- Search and dictionary configuration -*- lexical-binding: t; -*-

(when (string= (system-name) "ubuntu2204")
  (after! doom
    (add-to-list '+lookup-provider-url-alist
                 '("Bing" "https://cn.bing.com/search?go=Search&q=%s&qs=ds&form=QBRE"))))

(after! doom
  (add-to-list '+lookup-provider-url-alist
               '("NixOS Package Search" "https://search.nixos.org/packages?channel=25.11&query=%s")))

(use-package! bing-dict
  :hook (doom-first-file-hook . (lambda () (require 'bing-dict)))
  :custom
  (bing-dict-vocabulary-save t)
  (bing-dict-vocabulary-file (concat doom-user-dir "/etc/bing-dict/vocabulary.org"))
  :config
  (map! :leader :desc "Search word via Bing Dictionary" "sy" #'bing-dict-brief))

(use-package! eldoc
  :defer t
  :custom
  (eldoc-idle-delay 2))

(provide 'init-lookup)
;;; init-lookup.el ends here
