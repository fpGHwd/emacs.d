;;; init-setup.el --- Setup.el config -*- lexical-binding: t -*-
;;; Commentary:

;; setup extension

;;; Code:

(require 'setup)

(setup-define :defer
  (lambda (features)
    `(run-with-idle-timer 1 nil
                          (lambda ()
                            ,features)))
  :documentation "Delay loading the feature until a certain amount of idle time has passed."
  :repeatable t)

(setup-define :advice
  (lambda (symbol where function)
    `(advice-add ',symbol ,where ,function))
  :documentation "Add a piece of advice on a function.
See `advice-add' for more details."
  :after-loaded t
  :debug '(sexp sexp function-form)
  :ensure '(nil nil func)
  :repeatable t)

(setup-define :hooks
  (lambda (hook func)
    `(add-hook ',hook #',func))
  :documentation "Add pairs of hooks."
  :repeatable t)

(setup-define :after
  (lambda (feature &rest body)
    `(:with-feature ,feature
       (:when-loaded ,@body)))
  :documentation "Eval BODY after FEATURE."
  :indent 1)

(setup-define :face
  (lambda (face spec) `(custom-set-faces (quote (,face ,spec))))
  :documentation "Customize FACE to SPEC."
  :signature '(face spec ...)
  :debug '(setup)
  :repeatable t
  :after-loaded t)

(provide 'init-setup)
;;; init-setup.el ends here
