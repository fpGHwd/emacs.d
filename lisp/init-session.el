;;; init-session.el --- Credentials, persistence, and identity -*- lexical-binding: t; -*-

(require 'lib-util)

;; credentials
(setup auth-source
  (:option auth-sources (list (expand-file-name "etc/authinfo.gpg" doom-user-dir))))

;; recent files
(setup recentf
  (:after recentf 
    (setq recentf-max-saved-items 5000)))

(setup uniquify
  (:option uniquify-buffer-name-style 'forward
           uniquify-separator "/"))

(defun +wd/setup-uniquify-buffer-names ()
  (setup uniquify
    (:option uniquify-buffer-name-style 'forward
             uniquify-separator "/")))

;; workspaces / persp-mode
(setup persp-mode
  (:when-loaded
    (define-advice persp-delete-frame (:around (oldfn frame) +wd/live-frame-only)
      "Skip `persp-delete-frame' when FRAME is already dead."
      (when (frame-live-p frame)
        (funcall oldfn frame)))
    (add-hook 'persp-mode-hook #'+wd/setup-uniquify-buffer-names t)
    (when persp-mode
      (+wd/setup-uniquify-buffer-names))))

;; identity
(setq user-full-name "Wang Ding"
      user-mail-address "ggwdwhu@gmail.com"
      initial-scratch-message (concat ";; Happy hacking, " user-full-name " - Emacs ♥ you!\n\n"))

(setup gud
  (:when-loaded
    (add-to-list 'meow-mode-state-list '(gud-mode . insert))))

(provide 'init-session)
;;; init-session.el ends here
