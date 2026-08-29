;;; init-session.el --- Credentials, persistence, and identity -*- lexical-binding: t; -*-

;; credentials
(setup auth-source
  (:setopt auth-sources (list (expand-file-name "etc/authinfo.gpg" doom-user-dir))))

;; recent files
(setup recentf
  (:setopt recentf-max-saved-items 2000))

(setup uniquify
  (:setopt uniquify-buffer-name-style 'forward
           uniquify-separator "/"))

(defun +wd/setup-uniquify-buffer-names ()
  (setup uniquify
    (:setopt uniquify-buffer-name-style 'forward
             uniquify-separator "/")))

;; workspaces / persp-mode
(setup persp-mode
  (:hooks persp-mode-hook
          (:hook-options +wd/setup-uniquify-buffer-names :depth t))
  (:advice persp-delete-frame :around
           (:named +wd/live-frame-only
             (lambda (oldfn frame)
               "Skip `persp-delete-frame' when FRAME is already dead."
               (when (frame-live-p frame)
                 (funcall oldfn frame)))))
  (:when-loaded
    (when persp-mode
      (+wd/setup-uniquify-buffer-names))))

;; identity
(setup emacs
  (:setopt
   user-full-name "Wang Ding"
   user-mail-address "ggwdwhu@gmail.com"
   initial-scratch-message
   (concat ";; Happy hacking, " user-full-name " - Emacs ♥ you!\n\n")))

(setup gud
  (:after meow
    (:setopt (prepend meow-mode-state-list) '(gud-mode . insert))))


(setup json-mode
  (:match-file "Android.bp"))

(setup makefile-mode
  (:match-file "Makefile.*"))


(provide 'init-session)
;;; init-session.el ends here
