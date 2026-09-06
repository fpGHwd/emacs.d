;;; init-org-publish.el --- Org publishing and blog helpers -*- lexical-binding: t; -*-

(defvar org-publish-use-timestamps-flag)

(defun blog-post (title)
  "Create a blog post for TITLE."
  (interactive "sEnter title: ")
  (let ((post-file (concat "~/org/blog/current/posts/"
                           (format-time-string "%Y-%m-%d")
                           "-"
                           title
                           ".org")))
    (switch-to-buffer (find-file-noselect post-file))
    (insert (concat "#+startup: showall\n"
                    "#+options: toc:nil\n"
                    "#+begin_export html\n"
                    "---\n"
                    "layout     : post\n"
                    "title      : \n"
                    "categories : \n"
                    "tags       : \n"
                    "date       : \"" (format-time-string "%Y-%m-%d %H:%M:%S") "\"\n"
                    "---\n"
                    "#+end_export\n"
                    "#+TOC: headlines 2\n"))))

(defun publish-project (project no-cache)
  "Publish PROJECT, ignoring cache when NO-CACHE is y."
  (interactive "sName of project: \nsNo-cache?[y/n] ")
  (let ((org-publish-use-timestamps-flag
         (if (member no-cache '("y" "Y"))
             nil
           org-publish-use-timestamps-flag)))
    (org-publish-project project)))

(defun +wd/handle-image-in-markdown (_origin-path markdown-path)
  "Rewrite Org exported image links in MARKDOWN-PATH and deploy images."
  (interactive "fOrigin path: \nfMarkdown path: ")
  (let* ((hakyll-root-path "/home/wd/projects/2025/hakyll"))
    (with-temp-buffer
      (insert-file-contents markdown-path)
      (goto-char (point-min))
      (while (re-search-forward "\\(.+?\\)(\\(.+\\.png\\))" nil t)
        (let* ((image-src-path (string-remove-prefix "file://" (match-string 2)))
               (org-attach-path org-attach-id-dir)
               (image-deploy-prefix (concat hakyll-root-path "/images/org-attach"))
               (image-attach-relative-path (string-remove-prefix org-attach-path image-src-path))
               (image-ref-link (concat "/images/org-attach" image-attach-relative-path))
               (image-deploy-path (concat image-deploy-prefix image-attach-relative-path))
               (image-handle-cmd (concat (executable-find "magick") " "
                                         image-src-path " -strip -resize 50% -quality 50% "
                                         image-deploy-path)))
          (unless (file-exists-p (file-name-directory image-deploy-path))
            (make-directory (file-name-directory image-deploy-path) t))
          (replace-match image-ref-link nil nil nil 2)
          (unless (file-exists-p image-deploy-path)
            (shell-command image-handle-cmd nil))))
      (write-region (point-min) (point-max) markdown-path))))

(defun my/hakyll-site-build-async ()
  "Run hakyll-site-build asynchronously."
  (interactive)
  (let ((default-directory "~/org/blog/"))
    (make-process
     :name "hakyll-build"
     :buffer "*hakyll-build*"
     :command '("hakyll-site-build")
     :sentinel
     (lambda (_process event)
       (when (string= event "finished\n")
         (message "Hakyll build finished ✅"))))))

(defun my/org-insert-updated-timestamp (_backend)
  "Insert/update #+LAST_MODIFIED line before export."
  (save-excursion
    (goto-char (point-min))
    (if (re-search-forward "^updated    :.*$" nil t)
        (replace-match (concat "updated    : \"" (format-time-string "%Y-%m-%d %H:%M:%S") "\""))
      (when (re-search-forward "^---\n#\\+end_export$" nil t)
        (beginning-of-line)
        (forward-line -1)
        (open-line 1)
        (insert (concat "updated    : \"" (format-time-string "%Y-%m-%d %H:%M:%S") "\""))))))

(setup org
  (:with-feature ox-publish
    (:setopt
     org-publish-project-alist
     '(("org-blog"
        :base-directory "~/org/blog/current/posts/"
        :base-extension "org"
        :publishing-directory "~/org/blog/current/outputs/"
        :recursive t
        :publishing-function org-md-publish-to-md
        :publishing-extension "markdown"
        :headline-levels 4
        :body-only t)))
    (:hooks
     org-export-before-processing-functions my/org-insert-updated-timestamp
     org-publish-after-publishing-hook +wd/handle-image-in-markdown)
    (:setopt (prepend file-coding-system-alist) '("\\.bib" . utf-8))))

(provide 'init-org-publish)
;;; init-org-publish.el ends here
