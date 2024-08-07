;;; filtes-tests.el --- company-mode tests  -*- lexical-binding: t -*-

;; Copyright (C) 2016, 2021-2024  Free Software Foundation, Inc.

;; Author: Dmitry Gutov

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

(require 'company-tests)
(require 'company-files)

(ert-deftest company-files-candidates-normal ()
  (with-temp-buffer
    (insert company-dir)
    (let (company-files--completion-cache)
      (should (member "test/"
                      (company-files 'candidates
                                     company-dir))))))

(ert-deftest company-files-candidates-normal-root ()
  (with-temp-buffer
    (insert "/")
    (let (company-files--completion-cache)
      (should (member "bin/"
                      (company-files 'candidates "/"))))))

(ert-deftest company-files-candidates-excluding-dir ()
  (with-temp-buffer
    (insert company-dir)
    (let ((company-files-exclusions '("test/"))
          company-files--completion-cache)
      (should-not (member "test/"
                          (company-files 'candidates
                                         company-dir))))))

(ert-deftest company-files-candidates-excluding-files ()
  (with-temp-buffer
    (insert company-dir)
    (let ((company-files-exclusions '(".el"))
          company-files--completion-cache)
      (should-not (member "company.el"
                          (company-files 'candidates
                                         company-dir))))))

(ert-deftest company-files-candidates-excluding-dir-and-files ()
  (with-temp-buffer
    (insert company-dir)
    (let* ((company-files-exclusions '("test/" ".el"))
           company-files--completion-cache
           (files-candidates (company-files 'candidates company-dir)))
      (should-not (member "test/"
                          files-candidates))
      (should-not (member "company.el"
                          files-candidates)))))
