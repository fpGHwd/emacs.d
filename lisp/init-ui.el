;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(add-hook! 'doom-load-theme-hook
  (set-face-attribute 'font-lock-comment-face t :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face t :slant 'italic))

(add-to-list 'default-frame-alist '(fullscreen . fullboth))

(setq fancy-splash-image (file-truename (concat doom-user-dir "assets/2025/bitmap_resized_2.png"))
      imenu-auto-rescan t)

;; gif-screencast
;; https://github.com/Ambrevar/emacs-gif-screencast
;; (setup gif-screencast
;;   (:when-loaded
;;     (:option gif-screencast-convert-program (executable-find "magick")
;;              gif-screencast-convert-args '("convert" "-delay" "10" "-loop" "0")
;;              gif-screencast-args '("-x")
;;              gif-screencast-cropping-program "mogrify"
;;              gif-screencast-capture-format "ppm")
;;     (define-key gif-screencast-mode-map (kbd "<f8>") 'gif-screencast-toggle-pause)
;;     (define-key gif-screencast-mode-map (kbd "<f9>") 'gif-screencast-stop)
;;     (when (string= system-name "macbook-m1-pro")
;;       (advice-add
;;        #'gif-screencast--cropping-region
;;        :around
;;        (lambda (oldfun &rest r)
;;          (apply #'format "%dx%d+%d+%d"
;;                 (mapcar
;;                  (lambda (x) (* 2 (string-to-number x)))
;;                  (split-string (apply oldfun r) "[+x]"))))))))

(provide 'init-ui)
;;; init-ui.el ends here
