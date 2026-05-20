;;; init-tools-misc.el --- Optional tools and helper packages -*- lexical-binding: t; -*-

(use-package! bing-dict
  :hook (doom-first-file-hook . (lambda () (require 'bing-dict)))
  :custom
  (bing-dict-vocabulary-save t)
  (bing-dict-vocabulary-file (concat doom-user-dir "/etc/bing-dict/vocabulary.org"))
  :config
  (map! :leader :desc "Search word via Bing Dictionary" "sy" #'bing-dict-brief))

;; gif-screencast
;; https://github.com/Ambrevar/emacs-gif-screencast
(use-package! gif-screencast
  :defer t
  :custom
  (gif-screencast-convert-program (executable-find "magick"))
  (gif-screencast-convert-args '("convert" "-delay" "10" "-loop" "0"))
  (gif-screencast-args '("-x"))
  (gif-screencast-cropping-program "mogrify")
  (gif-screencast-capture-format "ppm")
  :config
  (with-eval-after-load 'gif-screencast
    (define-key gif-screencast-mode-map (kbd "<f8>") 'gif-screencast-toggle-pause)
    (define-key gif-screencast-mode-map (kbd "<f9>") 'gif-screencast-stop))

  (when (string= system-name "macbook-m1-pro")
    (advice-add
     #'gif-screencast--cropping-region
     :around
     (lambda (oldfun &rest r)
       (apply #'format "%dx%d+%d+%d"
              (mapcar
               (lambda (x) (* 2 (string-to-number x)))
               (split-string (apply oldfun r) "[+x]")))))))

(use-package! vterm
  :defer t
  :custom
  ;; Prefer vendored libvterm to avoid depending on system curses/ncurses headers.
  (vterm-module-cmake-args "-DUSE_SYSTEM_LIBVTERM=Off")
  (vterm-shell (let ((zsh-path (executable-find "zsh")))
                 (if zsh-path
                     zsh-path
                   (executable-find "bash"))))
  (vterm-tramp-shells '(("sshx" login-shell "/bin/zsh" "/bin/bash")
                        ("ssh" login-shell "/bin/zsh" "/bin/bash")
                        ("scp" login-shell "/bin/zsh" "/bin/bash")
                        ("docker" "/bin/zsh" "/bin/bash" "/bin/sh"))))

(use-package! magit-clone
  :defer t
  :custom
  (magit-clone-default-directory (concat (file-truename "~/projects/github/current") "/")))

(setup magit
  (:also-load lib-magit))

(use-package! pine-script-mode)

(provide 'init-tools-misc)
;;; init-tools-misc.el ends here
