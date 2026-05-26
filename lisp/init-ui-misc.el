;;; init-ui-misc.el --- UI-level identity and workspace settings -*- lexical-binding: t; -*-

(setq! +workspaces-data-file (concat (system-name) "_workspaces"))

(use-package! doom-ui
  :init
  (setq initial-scratch-message ";; Happy hacking,  - Emacs loves Melt!\12\12")
  :custom
  (initial-scratch-message (concat ";; Happy hacking, " user-full-name " - Emacs ♥ you!\n\n"))
  (fancy-splash-image (file-truename (concat doom-user-dir "assets/2025/bitmap_resized_2.png")))
  (imenu-auto-rescan t)
  (user-full-name "Wang Ding")
  (user-mail-address "ggwdwhu@gmail.com"))

(provide 'init-ui-misc)
;;; init-ui-misc.el ends here
