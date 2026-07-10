;;; init-session.el --- Credentials, persistence, and identity -*- lexical-binding: t; -*-

(require 'lib-util)

;; credentials
(setup auth-source
  (:option auth-source-save-behavior 'ask
           auth-sources (list (expand-file-name "etc/authinfo.gpg" doom-user-dir))))

;; recent files
(setup recentf
  (:when-loaded
    (:option recentf-max-saved-items 5000)))

;; workspaces
(setq! +workspaces-data-file (concat (system-name) "_workspaces"))

;; identity
(setq user-full-name "Wang Ding"
      user-mail-address "ggwdwhu@gmail.com"
      initial-scratch-message (concat ";; Happy hacking, " user-full-name " - Emacs ♥ you!\n\n"))

(provide 'init-session)
;;; init-session.el ends here
