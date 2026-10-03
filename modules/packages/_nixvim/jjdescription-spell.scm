;extends
; nvim-treesitter marks only the text of hand-written `JJ:` comments as
; spellable in a Jujutsu description. With a Treesitter highlighter active,
; Neovim checks nothing else, so the message itself went unchecked. Mark the
; subject and body as prose the way the gitcommit queries already do, and keep
; a conventional `type(scope):` prefix out of it.
(subject) @spell

(body_line) @spell

(prefix) @nospell
