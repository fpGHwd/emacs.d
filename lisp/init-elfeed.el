;;; ../dotfiles/doom.d/lisp/init-elfeed.el -*- lexical-binding: t; -*-

(use-package elfeed-tube
  :ensure t ;; or :straight t
  :after elfeed
  :demand t
  :config
  ;; (setq elfeed-tube-auto-save-p nil) ; default value
  ;; (setq elfeed-tube-auto-fetch-p t)  ; default value
  (elfeed-tube-setup)

  :bind (:map elfeed-show-mode-map
         ("F" . elfeed-tube-fetch)
         ([remap save-buffer] . elfeed-tube-save)
         :map elfeed-search-mode-map
         ("F" . elfeed-tube-fetch)
         ([remap save-buffer] . elfeed-tube-save))
  (add-to-list 'elfeed-feeds '("https://www.youtube.com/feeds/videos.xml?channel_id=PL3PYGQRVAjrORWRcEHX3dnICCPftJP5r-" bashbunni)))


(provide 'init-elfeed)
