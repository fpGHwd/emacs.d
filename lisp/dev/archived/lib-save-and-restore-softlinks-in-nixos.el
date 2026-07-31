;;; ../dotfiles/doom.d/lib/lib-handle-files.el -*- lexical-binding: t; -*-

;; find all softlink which point to a absolute path with prefix "/mnt/"
;; recursively in a given directory
(defun find-softlinks-pointing-to-mnt (directory)
  "Find all softlinks in DIRECTORY that point to absolute paths with prefix '/mnt/'."
  (let ((result '()))
    (dolist (file (directory-files-recursively directory ".*" t))
      (when (and (file-symlink-p file)
                 (let ((target (file-symlink-p file)))
                   (and target
                        (string-prefix-p "/mnt/" (expand-file-name target)))))
        (push file result)))
    result))

;; save result as a alist to a file
;; each element is (softlink . target)
;; a line a element
;; example: ("/home/wd/.config/data/stock" . "/mnt/home/data/stock")
;; to file: ~/.config/softlinks-mnt.el
;; with-emacs-lisp-mode

(defun save-softlinks-pointing-to-mnt (directory output-file)
  "Save all softlinks in DIRECTORY that point to absolute paths with prefix '/mnt/' to OUTPUT-FILE."
  (let ((softlinks (find-softlinks-pointing-to-mnt directory))
        (alist '()))
    (dolist (softlink softlinks)
      (let ((target (file-symlink-p softlink)))
        (when target
          (push (cons softlink (expand-file-name target)) alist))))
    (with-temp-file output-file
      (insert ";; Softlinks pointing to /mnt/\n")
      (insert ";; Generated on " (format-time-string "%Y-%m-%d %H:%M:%S") "\n\n")
      (insert "(setq softlinks-mnt '(\n")
      (dolist (pair alist)
        (insert (format "  (\"%s\" . \"%s\")\n" (car pair) (cdr pair))))
      (insert "))\n"))))

;; restore softlinks from the file
;; read the file ~/.config/softlinks-mnt.el
;; and recreate the softlinks

(defun restore-softlinks-pointing-to-mnt (input-file)
  "Restore softlinks from INPUT-FILE."
  (load-file input-file)
  (dolist (pair softlinks-mnt)
    (let ((softlink (car pair))
          (target (cdr pair)))
      (when (and (not (file-exists-p softlink))
                 (file-exists-p target))
        ;; Ensure the parent directory exists
        (let ((parent-dir (file-name-directory softlink)))
          (unless (file-exists-p parent-dir)
            (make-directory parent-dir t)))
        (make-symbolic-link target softlink)))))


;; auto backup file ~/.zsh_history to /mnt/nas/data-wd/database/zsh/history/zshrc_history-20260129-210222.history
(defun auto-backup-zshrc-to-mnt ()
  "Automatically backup ~/.zshrc to /mnt/nas/data-wd/database/zsh/history/ with timestamp."
  (let* ((source-file (expand-file-name "~/.zsh_history"))
         (timestamp (format-time-string "%Y%m%d-%H%M%S"))
         (backup-dir "/mnt/nas/data-wd/database/zsh/history/")
         (backup-file (concat backup-dir "zsh_history-" timestamp)))
    (unless (file-exists-p backup-dir)
      (make-directory backup-dir t))
    (copy-file source-file backup-file t)))

;; Example usage:
;; (save-softlinks-pointing-to-mnt "/home/wd/" "~/log/2026/softlink.el")


(defun +wd/remove-deprecated-files (dir)
  "Delete file marked as *-deprecated"
  (interactive "DSelect directory: ")
  (if (string-suffix-p "-deprecated" dir)
      (let (dir-rm (string-remove-suffix "-deprecated" dir))
        (if (file-exists-p dir-rm)
            ;; TODO: maybe file 
            (progn (delete-directory dir-rm t)
                   (delete-directory dir t))))))

(provide 'lib-save-and-restore-softlinks-in-nixos)
