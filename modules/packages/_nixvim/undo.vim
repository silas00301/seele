" Undo contains previous file contents, so keep its directory private.
set noundofile
let s:undo_dir = stdpath('state') .. '/undo'
try
  if !isdirectory(s:undo_dir)
    call mkdir(s:undo_dir, 'p', 0700)
  endif
  if getftype(s:undo_dir) ==# 'dir' && setfperm(s:undo_dir, 'rwx------')
    let &undodir = escape(s:undo_dir, ',\') .. '//'
    set undofile
  endif
catch
  " Ordinary editing still works when the state directory is unavailable.
  set noundofile
endtry

function! s:IsSensitiveUndoPath(path) abort
  if a:path =~# '\v(^|/)(\.ssh|\.gnupg|\.aws|\.kube)/'
        \ || a:path =~# '\v(^|/)(\.env($|\.)|.*\.(pem|key|gpg)$)'
        \ || a:path =~# '\v(^|/)(\.netrc|\.npmrc|\.pypirc|\.git-credentials)$'
        \ || a:path =~# '\v(^|/)(\.config/gh/hosts\.yml|\.docker/config\.json)$'
        \ || a:path =~# '/sops/age/'
    return 1
  endif
  " Tools can move their auth files outside the conventional home paths.
  let config_home = empty($XDG_CONFIG_HOME) ? $HOME .. '/.config' : $XDG_CONFIG_HOME
  let auth_files = [config_home .. '/gh/hosts.yml']
  if !empty($GH_CONFIG_DIR)
    call add(auth_files, $GH_CONFIG_DIR .. '/hosts.yml')
  endif
  if !empty($DOCKER_CONFIG)
    call add(auth_files, $DOCKER_CONFIG .. '/config.json')
  endif
  for file in auth_files
    let file = fnamemodify(file, ':p')
    if a:path ==# file || a:path ==# resolve(file)
      return 1
    endif
  endfor
  for directory in ['/tmp', '/var/tmp', '/private/tmp', '/private/var/tmp', '/dev/shm', '/run/user', $TMPDIR, $XDG_RUNTIME_DIR]
    if empty(directory)
      continue
    endif
    let directory = substitute(resolve(fnamemodify(directory, ':p')), '/$', '', '')
    if a:path ==# directory || stridx(a:path, directory .. '/') == 0
      return 1
    endif
  endfor
  return 0
endfunction

function! s:ProtectUndo() abort
  let path = expand('<afile>:p')
  " Check the displayed path as well as a symlink's destination.
  if s:IsSensitiveUndoPath(path) || s:IsSensitiveUndoPath(resolve(path))
    setlocal noundofile
  endif
  " Never turn it back on here: respect :setlocal noundofile and secret editors.
endfunction

augroup seele_private_undo
  autocmd!
  autocmd BufReadPre,BufNewFile,BufFilePost,BufWritePre * call <SID>ProtectUndo()
augroup END
