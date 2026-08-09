;;; init-ui.el --- Theme, frame, and visual appearance -*- lexical-binding: t; -*-

(add-hook! 'doom-load-theme-hook
  (set-face-attribute 'font-lock-comment-face t :slant 'italic)
  (set-face-attribute 'font-lock-keyword-face t :slant 'italic))

(setq default-frame-alist (assq-delete-all 'fullscreen default-frame-alist))

(defun +wd/macos-native-fullscreen-frame (frame)
  "Enter macOS native fullscreen for FRAME after it is visible."
  (when (and (eq system-type 'darwin)
             (display-graphic-p frame))
    (run-at-time
     "0.5 sec" nil
     (lambda (frame)
       (when (frame-live-p frame)
         (with-selected-frame frame
           (unless (eq (frame-parameter frame 'fullscreen) 'fullscreen)
             (call-interactively
              (if (fboundp 'mac-toggle-frame-fullscreen)
                  #'mac-toggle-frame-fullscreen
                #'toggle-frame-fullscreen))))))
     frame)))

(when (eq system-type 'darwin)
  (add-hook 'emacs-startup-hook
            (lambda () (+wd/macos-native-fullscreen-frame (selected-frame))))
  (add-hook 'after-make-frame-functions #'+wd/macos-native-fullscreen-frame))

(setq imenu-auto-rescan t)

(setup dirvish
  (:when-loaded
    (:with-map dirvish-mode-map
      (:bind "TAB" dirvish-subtree-toggle))))

(provide 'init-ui)
;;; init-ui.el ends here
