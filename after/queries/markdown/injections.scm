; extends

; Inject LaTeX into code blocks with =latex
(fenced_code_block
  (info_string
    (language) @_lang)
  (code_fence_content) @injection.content
  (#eq? @_lang "=latex")
  (#set! injection.language "latex"))
