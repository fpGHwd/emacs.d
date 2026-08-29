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
    (let (name)
      (when (eq (car-safe function) :named)
        (unless (= (length function) 3)
          (error "Invalid named advice: %S" function))
        (setq name (cadr function)
              function (caddr function)))
      (setq function
            (cond ((eq (car-safe function) 'function) function)
                  ((eq (car-safe function) 'quote) `#',(cadr function))
                  ((symbolp function) `#',function)
                  (t function)))
      `(advice-add ',symbol ,where ,function
                   ,@(when name `('((name . ,name)))))))
  :documentation "Add a piece of advice on a function.
Use `(:named NAME FUNCTION)' to give anonymous advice a stable reload identity.
See `advice-add' for more details."
  :after-loaded t
  :debug '(sexp sexp sexp)
  :repeatable t)

(setup-define :hooks
  (lambda (hook func)
    (let (depth local)
      (when (eq (car-safe func) :hook-options)
        (let ((options (cddr func)))
          (unless (cadr func)
            (error "Missing hook function: %S" func))
          (let ((tail options))
            (while tail
              (unless (and (memq (car tail) '(:depth :local)) (cdr tail))
                (error "Invalid hook options: %S" options))
              (setq tail (cddr tail))))
          (setq depth (plist-get options :depth)
                local (plist-get options :local)
                func (cadr func))))
      (setq func
            (cond ((eq (car-safe func) 'function) func)
                  ((eq (car-safe func) 'quote) `#',(cadr func))
                  ((symbolp func) `#',func)
                  (t func)))
      `(add-hook ',hook ,func ,depth ,local)))
  :documentation "Add pairs of hooks.
Use `(:hook-options FUNCTION :depth DEPTH :local LOCAL)' for optional arguments."
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
