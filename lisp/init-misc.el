;;; lisp/init-misc.el -*- lexical-binding: t; -*-

;; session defaults
(use-package! auth-source
  :defer t
  :custom
  (auth-source-save-behavior 'ask)
  (auth-sources '("~/.config/emacs.d/etc/authinfo.gpg")))
