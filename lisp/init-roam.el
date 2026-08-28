;;; init-roam.el --- org-roam and org-roam-ui -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'seq)
(require 'vulpea)

(setup org-roam
  (:hooks org-mode-hook +wd/org-roam-maybe-track-project-tag)
  (:option org-roam-directory "~/org/roam")
  (:advice org-agenda-files :filter-return #'dynamic-agenda-files-advice))

(defun vulpea-buffer-p ()
  "Return non-nil if the currently visited buffer is a note."
  (and buffer-file-name
       (or (string-prefix-p
            (expand-file-name (file-name-as-directory "~/org/roam"))
            (file-name-directory buffer-file-name))
           (string-prefix-p
            (expand-file-name (file-name-as-directory "~/org/work/zone/roam"))
            (file-name-directory buffer-file-name)))))

(defun vulpea-project-p ()
  "Return non-nil if current buffer has any todo entry."
  (or (seq-find
       (lambda (type)
         (eq type 'todo))
       (org-element-map
           (org-element-parse-buffer 'headline)
           'headline
         (lambda (h)
           (org-element-property :todo-type h))))
      (seq-find
       (lambda (type)
         (and (or (eq (org-element-property :type (nth 0 type)) 'active)
                  (eq (org-element-property :type (nth 0 type)) 'active-range)
                  (eq (org-element-property :type (nth 1 type)) 'active)
                  (eq (org-element-property :type (nth 1 type)) 'active-range))
              (not (nth 2 type))))
       (org-element-map
           (org-element-parse-buffer 'headline)
           'headline
         (lambda (h)
           (list (org-element-property :scheduled h)
                 (org-element-property :deadline h)
                 (org-element-property :closed h)))))))

(defun vulpea-project-update-tag (&optional arg)
  "Update PROJECT tag in the current buffer."
  (interactive "P")
  (when (and (not (active-minibuffer-window))
             (vulpea-buffer-p))
    (save-excursion
      (goto-char (point-min))
      (let* ((tags (vulpea-buffer-tags-get))
             (original-tags tags))
        (if (vulpea-project-p)
            (setq tags (cons "roam-agenda" tags))
          (setq tags (remove "roam-agenda" tags)))
        (setq tags (seq-uniq tags))
        (when (or (seq-difference tags original-tags)
                  (seq-difference original-tags tags))
          (apply #'vulpea-buffer-tags-set tags))))))

(defun my/org-roam-filter-by-tag (tag-name)
  (lambda (node)
    (member tag-name (org-roam-node-tags node))))

(defun my/org-roam-list-notes-by-tag (tag-name)
  (mapcar #'org-roam-node-file
          (seq-filter
           (my/org-roam-filter-by-tag tag-name)
           (org-roam-node-list))))

(defun dynamic-agenda-files-advice (orig-val)
  (let ((roam-agenda-files (delete-dups (my/org-roam-list-notes-by-tag "roam-agenda"))))
    (cl-union orig-val roam-agenda-files :test #'equal)))

(defun +wd/org-roam-maybe-track-project-tag ()
  "Only track Vulpea tags in Org Roam buffers."
  (when (vulpea-buffer-p)
    (add-hook 'before-save-hook #'vulpea-project-update-tag nil t)))

;; refs: https://org-roam.discourse.group/t/v2-ignore-headline-node-with-org-id/1793 , https://www.orgroam.com/manual.html#When-to-cache

;; todo: 如何在反向链接的 buffer 中区分显示完成和未完成的任务，并过滤分类

(provide 'init-roam)
;;; init-roam.el ends here
