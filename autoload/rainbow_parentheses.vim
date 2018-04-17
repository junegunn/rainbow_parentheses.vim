"==============================================================================
"  Description: Rainbow colors for parentheses, based on rainbow_parenthsis.vim
"               by Martin Krischik and others.
"==============================================================================

function! s:uniq(list)
  let ret = []
  let map = {}
  for items in a:list
    let ok = 1
    for item in filter(copy(items), '!empty(v:val)')
      if has_key(map, item)
        let ok = 0
      endif
      let map[item] = 1
    endfor
    if ok
      call add(ret, items)
    endif
  endfor
  return ret
endfunction

" Excerpt from https://github.com/junegunn/vim-journal
" http://stackoverflow.com/questions/27159322/rgb-values-of-the-colors-in-the-ansi-extended-colors-index-17-255
let s:ansi16 = {
  \ 0:  '#000000', 1:  '#800000', 2:  '#008000', 3:  '#808000',
  \ 4:  '#000080', 5:  '#800080', 6:  '#008080', 7:  '#c0c0c0',
  \ 8:  '#808080', 9:  '#ff0000', 10: '#00ff00', 11: '#ffff00',
  \ 12: '#0000ff', 13: '#ff00ff', 14: '#00ffff', 15: '#ffffff' }
function! s:rgb(color)
  if a:color[0] == '#'
    let r = str2nr(a:color[1:2], 16)
    let g = str2nr(a:color[3:4], 16)
    let b = str2nr(a:color[5:6], 16)
    return [r, g, b]
  endif

  let ansi = str2nr(a:color)

  if ansi < 16
    return s:rgb(s:ansi16[ansi])
  endif

  if ansi >= 232
    let v = (ansi - 232) * 10 + 8
    return [v, v, v]
  endif

  let r = (ansi - 16) / 36
  let g = ((ansi - 16) % 36) / 6
  let b = (ansi - 16) % 6

  return map([r, g, b], 'v:val > 0 ? (55 + v:val * 40) : 0')
endfunction

" http://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
" http://alienryderflex.com/hsp.html
function! s:brightness_(rgb)
  let [max, min] = map([max(a:rgb), min(a:rgb)], 'v:val / 255.0')
  let [r, g, b]  = map(a:rgb, 'v:val / 255.0')
  if max == min
    return (max + min) / 2.0
  endif
  return sqrt(0.299 * r * r + 0.587 * g * g + 0.114 * b * b)
endfunction

let s:brightness = {}
function! s:brightness(color)
  let color = filter(copy(a:color), '!empty(v:val)')[0]
  if has_key(s:brightness, color)
    return s:brightness[color]
  endif
  let b = s:brightness_(s:rgb(color))
  let s:brightness[color] = b
  return b
endfunction

function! s:colors_to_hi(colors)
  return
    \ join(
    \   values(
    \     map(
    \       filter({ 'ctermfg': a:colors[0], 'guifg': a:colors[1] },
    \              '!empty(v:val)'),
    \       'v:key."=".v:val')), ' ')
endfunction

function! s:extract_fg(line)
  let cterm = matchstr(a:line, 'ctermfg=\zs\S*\ze')
  let gui   = matchstr(a:line, 'guifg=\zs\S*\ze')
  return [cterm, gui]
endfunction

function! s:blacklist()
  redir => output
    silent! hi Normal
  redir END
  let line  = split(output, '\n')[0]
  let cterm = matchstr(line, 'ctermbg=\zs\S*\ze')
  let gui   = matchstr(line, 'guibg=\zs\S*\ze')
  let blacklist = {}
  if !empty(cterm) | let blacklist[cterm] = 1 | endif
  if !empty(gui)   | let blacklist[gui]   = 1 | endif
  return [blacklist, s:extract_fg(line)]
endfunction

let s:colors = { 'light': {}, 'dark': {} }
function! s:extract_colors()
  if exists('g:colors_name') && has_key(s:colors[&background], g:colors_name)
    return s:colors[&background][g:colors_name]
  endif
  redir => output
    silent hi
  redir END
  let lines = filter(split(output, '\n'), 'v:val =~# "fg" && v:val !~? "links" && v:val !~# "bg"')
  let colors = s:uniq(reverse(map(lines, 's:extract_fg(v:val)')))
  let [blacklist, fg] = s:blacklist()
  for c in get(g:, 'rainbow#blacklist', [])
    let blacklist[c] = 1
  endfor
  let colors = filter(colors,
        \ '!has_key(blacklist, v:val[0]) && !has_key(blacklist, v:val[1])')

  if !empty(filter(copy(fg), '!empty(v:val)'))
    let nb = s:brightness(fg)
    let [first, second] = [[], []]
    for cpair in colors
      let b = s:brightness(cpair)
      let diff = abs(nb - b)
      if diff <= 0.25
        call add(first, cpair)
      elseif diff <= 0.5
        call add(second, cpair)
      endif
    endfor
    let colors = extend(first, second)
  endif

  let colors = map(colors, 's:colors_to_hi(v:val)')
  if exists('g:colors_name')
    let s:colors[&background][g:colors_name] = colors
  endif
  return colors
endfunction

function! s:show_colors()
  for level in reverse(range(1, s:max_level))
    execute 'hi rainbowParensShell'.level
  endfor
endfunction

let s:generation = 0
function! rainbow_parentheses#activate(...)
  let force = get(a:000, 0, 0)
  if exists('#rainbow_parentheses') && get(b:, 'rainbow_enabled', -1) == s:generation && !force
    return
  endif

  let s:generation += 1
  let s:max_level = get(g:, 'rainbow#max_level', 16)
  let colors = exists('g:rainbow#colors') ?
    \ map(copy(g:rainbow#colors[&bg]), 's:colors_to_hi(v:val)') :
    \ s:extract_colors()

  for level in range(1, s:max_level)
    let col = colors[(level - 1) % len(colors)]
    execute printf('hi rainbowParensShell%d %s', s:max_level - level + 1, col)
  endfor
  call s:regions(s:max_level)

  command! -bang -nargs=? -bar RainbowParenthesesColors call s:show_colors()
  augroup rainbow_parentheses
    autocmd!
    autocmd ColorScheme,Syntax * call rainbow_parentheses#activate(1)
  augroup END
  let b:rainbow_enabled = s:generation
endfunction

function! rainbow_parentheses#deactivate()
  if exists('#rainbow_parentheses')
    for level in range(1, s:max_level)
      " FIXME How to cope with changes in rainbow#max_level?
      silent! execute 'hi clear rainbowParensShell'.level
      " FIXME buffer-local
      silent! execute 'syntax clear rainbowParens'.level
    endfor
    augroup rainbow_parentheses
      autocmd!
    augroup END
    augroup! rainbow_parentheses
    delc RainbowParenthesesColors
  endif
endfunction

function! rainbow_parentheses#toggle()
  if exists('#rainbow_parentheses')
    call rainbow_parentheses#deactivate()
  else
    call rainbow_parentheses#activate()
  endif
endfunction

function! s:regions(max)
  let pairs = get(g:, 'rainbow#pairs', [['(',')']])
  for level in range(1, a:max)
    let cmd = 'syntax region rainbowParens%d matchgroup=rainbowParensShell%d start=/%s/ end=/%s/ contains=%s,@Spell'
    let children = extend(['TOP'], map(range(level, a:max), '"rainbowParens".v:val'))
    for pair in pairs
      let [open, close] = map(copy(pair), 'escape(v:val, "[]/")')
      execute printf(cmd, level, level, open, close, join(children, ','))
    endfor
  endfor
endfunction

