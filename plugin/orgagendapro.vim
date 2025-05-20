augroup OrgHighlights
  autocmd!
  autocmd FileType org syntax match OrgCompletedItem /^.*\[X\].*$/  
  autocmd FileType org highlight OrgCompletedItem ctermfg=DarkGray guifg=Gray40
  
  autocmd FileType org syntax match OrgUncheckedCheckbox /\[ \]/ containedin=ALL
  autocmd FileType org syntax match OrgUncheckedCheckbox /\[-\]/ containedin=ALL
  autocmd FileType org highlight OrgUncheckedCheckbox  guifg=DarkOrange
  
  autocmd FileType org syntax match OrgHeader /^\*.*$/
  autocmd FileType org highlight OrgHeader term=bold cterm=bold gui=bold guifg=DarkOrange

  autocmd FileType org syntax match OrgDoneHeader /^\*\+\s\+DONE\s.*$/
  autocmd FileType org highlight OrgDoneHeader ctermfg=DarkGray guifg=Gray40 term=bold cterm=bold gui=bold

  " Add priority pattern and highlight
  autocmd FileType org syntax match OrgPriority /\[#[A-N]\]/ containedin=OrgHeader,OrgDoneHeader
  autocmd FileType org highlight OrgPriority guifg=DarkGreen gui=bold
  
  autocmd FileType org syntax match OrgScheduled /SCHEDULED:/
  if exists('g:org_highlight_foreground') && g:org_highlight_foreground != ''
    autocmd FileType org execute "highlight OrgScheduled term=bold cterm=bold gui=bold guifg=" . g:org_highlight_foreground
  else
    autocmd FileType org highlight OrgScheduled term=bold cterm=bold gui=bold
  endif
  
  autocmd FileType org syntax match OrgDeadline /DEADLINE:/
  if exists('g:org_highlight_foreground') && g:org_highlight_foreground != ''
    autocmd FileType org execute "highlight OrgDeadline term=bold cterm=bold gui=bold guifg=" . g:org_highlight_foreground
  else
    autocmd FileType org highlight OrgDeadline term=bold cterm=bold gui=bold
  endif
  
  autocmd FileType org syntax match OrgClosed /CLOSED:/
  autocmd FileType org highlight OrgClosed term=bold cterm=bold gui=bold ctermfg=DarkGray guifg=Gray40
  
  autocmd FileType org syntax match OrgHyperlink /https\?:\/\/[A-Za-z0-9_\/.#?&=~-]\+/
  autocmd FileType org highlight OrgHyperlink term=underline cterm=underline gui=underline 
augroup END

au BufRead,BufNewFile *.org set filetype=org

function! LineIsOrgHeader(line)
  return a:line[0] ==# '*'
endfunction

function! GetCurrentLineOrgHeaderLevel()
  let line = getline('.')
  if !LineIsOrgHeader(line)
    return 0
  endif
  return len(matchstr(line, '^\*\+'))
endfunction

function! AddOrgDateText(line_num, date_type, date_text)
  let next_line_num = a:line_num + 1
  let next_line = getline(next_line_num)
  
  let formatted_date_text = a:date_type . ": " . a:date_text
  
  if next_line =~# '^\s*$' || next_line_num > line('$')
    call append(a:line_num, "  " . formatted_date_text)
    return next_line_num
  elseif next_line =~# '<\d\{4\}-\d\{2\}-\d\{2\}'
    call setline(next_line_num, "  " . formatted_date_text . " " . next_line)
    return next_line_num
  else
    call append(a:line_num, "  " . formatted_date_text)
    return next_line_num
  endif
endfunction

function! AddOrgDateWithType(date_type)
  let line = getline('.')
  if !LineIsOrgHeader(line)
    echo "Not on a header line"
    return
  endif
  
  let today = strftime('%Y-%m-%d %a')
  let date_text = "<" . today . ">"
  
  call AddOrgDateText(line('.'), a:date_type, date_text)
endfunction

function! HandleOrgEnterKey()
  let line = getline('.')

  if LineIsOrgHeader(line)
    let header_text = substitute(line, '^\*\+\s*', '', '')
    
    let next_line_num = line('.') + 1
    let next_line = getline(next_line_num)
    let recurring_pattern = '<\d\{4\}-\d\{2\}-\d\{2\}\s\+\w\{3\}\(\s\+\d\{1,2}:\d\{2\}\(-\d\{1,2}:\d\{2\}\)\?\)\?\s\+\(+\d\+[dwmy]\)'

    if next_line =~# recurring_pattern && header_text =~# '^TODO\s'
      let recurring_match = matchlist(next_line, recurring_pattern)
      let recurring_spec = recurring_match[3]  " e.g., '+1d', '+2w', '+3m', '+1y'
      let increment = str2nr(recurring_spec[1:-2])  " remove '+' and unit, convert to number
      let unit = recurring_spec[-1:]  " get 'd', 'w', 'm', or 'y'

      let date_tag_pos = match(next_line, '<\d\{4\}-\d\{2\}-\d\{2\}')
      
      call cursor(next_line_num, date_tag_pos + 1)  
      
      if unit ==# 'd'
        call ShiftOrgDateDays(increment)
      elseif unit ==# 'w'
        call ShiftOrgDateDays(increment * 7)
      elseif unit ==# 'm'
        call ShiftOrgDateMonths(increment)
      elseif unit ==# 'y'
        call ShiftOrgDateYears(increment)
      endif
      
      call cursor(line('.') - 1, col('.'))
      return
    endif
    
    if header_text =~# '^TODO\s' 
      call MarkCurrentLineAsClosed('TODO', line)
    elseif header_text =~# '^WAIT\s' 
      call MarkCurrentLineAsClosed('WAIT', line)
    elseif header_text =~# '^DONE\s'
      let new_header = substitute(line, 'DONE', 'TODO', '')
      call setline('.', new_header)
    endif
    return
  endif

  if match(line, '- \[ \]') >= 0
    call setline('.', substitute(line, '- \[ \]', '- [-]', ''))
    return
  elseif match(line, '- \[-\]') >= 0
    call setline('.', substitute(line, '- \[-\]', '- [X]', ''))
    return
  elseif match(line, '- \[X\]') >= 0
    call setline('.', substitute(line, '- \[X\]', '- [ ]', ''))
    return
  endif

  let cursor_col = col('.')
  let url_pattern = 'https\?://[A-Za-z0-9_/.#?&=-]\+'

  let url_start = match(line, url_pattern, 0)
  if url_start >= 0
    let url_end = match(line, '[[:space:]<>()]', url_start) - 1
    if url_end < 0
      let url_end = len(line) - 1
    endif
    
    if cursor_col >= url_start + 1 && cursor_col <= url_end + 1
      let url = strpart(line, url_start, url_end - url_start + 1)
      call system('start "" "' . url . '"')
      return
    endif
  endif
endfunction
autocmd FileType org nnoremap <buffer> <CR> :call HandleOrgEnterKey()<CR>

function! MarkCurrentLineAsClosed(previousState, line)
  let new_header = substitute(a:line, a:previousState, 'DONE', '')
  call setline('.', new_header)
  let current_datetime = strftime('[%Y-%m-%d %a %H:%M]')
  call AddOrgDateText(line('.'), 'CLOSED', current_datetime)
endfunction

function! LineIsOrgCheckbox(line)
  return match(a:line, '^\(\s*\)- \[\s*[X -]\s*\]') >= 0
endfunction

function! AddNewItemAtBelowLine()
  let line = getline('.')
  if LineIsOrgCheckbox(line)
    call HandleAddNewCheckboxAtBelowLine(line)
    return
  endif
  if LineIsOrgHeader(line)
    call HandleAddNewHeaderAtBelowLine(line)
    return
  endif

  execute "normal! o"
endfunction

function! HandleAddNewHeaderAtBelowLine(line)
  let header_asterix_count = GetAsterixCountFromHeaderLine(a:line)
  let current_line_nr = line('.')
  let new_header = repeat('*', header_asterix_count) . ' '
  let next_line_nr = current_line_nr + 1
  let file_end = line('$')
  while next_line_nr <= file_end
    let next_line = getline(next_line_nr)
    if LineIsOrgHeader(next_line)
      " Found a header
      break
    endif
    let next_line_nr += 1
  endwhile
  let insert_position = next_line_nr - 1
  call append(insert_position, new_header)
  call cursor(insert_position + 1, len(new_header) + 1)
  startinsert!
endfunction

function! AddNewItemAtAboveLine()
  let line = getline('.')
  if LineIsOrgCheckbox(line)
    call HandleAddNewCheckboxAtAboveLine(line)
    return
  endif
  if LineIsOrgHeader(line)
    call HandleAddNewHeaderAtAboveLine(line)
    return
  endif

  execute "normal! o"
endfunction


function! HandleAddNewCheckboxAtAboveLine(line)
  let indentation = matchstr(a:line, '^\s*')
  let new_line = indentation . '- [ ] '
  call append(line('.') - 1, new_line)
  normal! k$
  startinsert!
endfunction

function! HandleAddNewHeaderAtAboveLine(line)
  let header_asterix_count = GetAsterixCountFromHeaderLine(a:line)
  let current_line_nr = line('.')
  let new_header = repeat('*', header_asterix_count) . ' '
  let previous_line_nr = current_line_nr - 1
  let insert_position = previous_line_nr 
  call append(insert_position, new_header)
  call cursor(insert_position + 1, len(new_header) + 1)
  startinsert!
endfunction

function! HandleAddNewCheckboxAtBelowLine(line)
  let indentation = matchstr(a:line, '^\s*')
  let new_line = indentation . '- [ ] '
  call append(line('.'), new_line)
  normal! j$
  startinsert!
endfunction

autocmd FileType org nnoremap <buffer> <C-CR> :call AddNewItemAtBelowLine()<CR>
autocmd FileType org nnoremap <buffer> <C-S-CR> :call AddNewItemAtAboveLine()<CR>

function! SearchForwardOpenChecklistItem()
  call SearchForward('\(- \[ \]\|- \[-\]\)')
endfunction
autocmd FileType org nnoremap <buffer> <C-j> :call SearchForwardOpenChecklistItem()<CR>

function! SearchBackOpenChecklistItem()
  call SearchBackward('\(- \[ \]\|- \[-\]\)')
endfunction
autocmd FileType org nnoremap <buffer> <S-j> :call SearchBackOpenChecklistItem()<CR>

function! SearchForwardOrgHeader()
  call SearchForward('^\*\+\s')
endfunction
autocmd FileType org nnoremap <buffer> <C-h> :call SearchForwardOrgHeader()<CR>

function! SearchBackwardOrgHeader()
  call SearchBackward('^\*\+\s')
endfunction
autocmd FileType org nnoremap <buffer> <S-h> :call SearchBackwardOrgHeader()<CR>

function! SearchForward(pattern)
    let @/ = a:pattern
    normal! n
    call feedkeys(":nohlsearch\<CR>", 'n')
endfunction

function! SearchBackward(pattern)
    let @/ = a:pattern
    normal! N
    call feedkeys(":nohlsearch\<CR>", 'n')
endfunction

let g:narrow_view_active = 0

function! DisableNarrow()
    if g:narrow_view_active == 0
      return
    endif
    normal! zR
    let g:narrow_view_active = 0
endfunction

function! EnableNarrow()
    let l:current_line = line('.')
    let l:current_col = col('.')
    
    let l:current_header = l:current_line
    let l:current_level = 0
    
    while l:current_header > 0
        let l:old_pos = getpos('.')
        call cursor(l:current_header, 1)
        
        if LineIsOrgHeader(getline('.'))
            let l:current_level = GetCurrentLineOrgHeaderLevel()
            call setpos('.', l:old_pos)
            break
        endif
        
        call setpos('.', l:old_pos)
        let l:current_header -= 1
    endwhile
    
    if l:current_header == 0
        let l:current_header = 1
        let l:current_level = 1
    endif
    
    let l:next_header = l:current_line + 1
    let l:last_line = line('$')
    
    while l:next_header <= l:last_line
        let l:line = getline(l:next_header)
        if l:line =~# '^\*'
            let l:next_level = len(matchstr(l:line, '^\*\+'))
            if l:next_level <= l:current_level
                break
            endif
        endif
        let l:next_header += 1
    endwhile
    
    if l:next_header > l:last_line
        let l:next_header = l:last_line + 1
    endif
    
    normal! zE  
    
    if l:current_header > 1
        execute "1," . (l:current_header - 1) . "fold"
    endif
    
    if l:next_header <= l:last_line
        execute l:next_header . "," . l:last_line . "fold"
    endif

    call cursor(l:current_line, l:current_col)
    
    let g:narrow_view_active = 1
    echo "Narrowed view to current section (level " . l:current_level . ")"
endfunction
autocmd FileType org nnoremap <buffer> <Space>msn :call EnableNarrow()<CR>
autocmd FileType org nnoremap <buffer> <Space>msN :call DisableNarrow()<CR>

function! ShiftOrgDateYears(years)
  let line = getline('.')
  let cursor_col = col('.')
  let [year, month, day, day_name, postfix, match_start, date_end, date_str] = ExtractDateFromCurrentLine()
  let year = year + 1
  let month_str = EnsurePrefixZeroIfLessThanTen(month)
  let day_str = EnsurePrefixZeroIfLessThanTen(day)
  let new_date = year . "-" . month_str . "-" . day_str
  let new_date_tag = '<' . new_date . ' ' . day_name . postfix . '>'
  call UpdateDateOnCurrentLine(line, match_start, new_date_tag, date_end)
  call cursor(line('.'), cursor_col)
endfunction

function! EnsurePrefixZeroIfLessThanTen(numb)
  if type(a:numb) == v:t_string && len(a:numb) >= 2
     return a:numb
  endif

  if a:numb < 10
    return "0" . a:numb 
  endif
  return a:numb . ""
endfunction

function! ShiftOrgDateMonths(months)
  let line = getline('.')
  let cursor_col = col('.')
  if a:months < 0
    echo "Invalid months: must be non-negative"
    return
  endif


  let [year, month, day, day_name, postfix, match_start, date_end, date_str] = ExtractDateFromCurrentLine()
  let month = month + a:months
  if month > 12
    let year = year + (month / 12) 
    let month = month % 12
  endif
  let month_str = EnsurePrefixZeroIfLessThanTen(month)
  let day_str = EnsurePrefixZeroIfLessThanTen(day)

  let new_date = year . "-" . month_str . "-" . day_str
  let new_date_tag = '<' . new_date . ' ' . day_name . postfix . '>'

  call UpdateDateOnCurrentLine(line, match_start, new_date_tag, date_end)
  call cursor(line('.'), cursor_col)
endfunction

function! UpdateDateOnCurrentLine(line, match_start, new_date_tag, date_end)
  let new_line = strpart(a:line, 0, a:match_start) . a:new_date_tag . strpart(a:line, a:date_end + 1)
  call setline('.', new_line)
endfunction

function! ExtractDateFromCurrentLine()
  let line = getline('.')
  let cursor_col = col('.')
  let date_pattern = '<\(\d\{4\}-\d\{2\}-\d\{2\}\)\s\+\(\a\{3\}\)\(.*\)>'
  
  let start_pos = cursor_col - 15
  
  while 1
    let match_start = match(line, date_pattern, start_pos)
    if match_start == -1
      if start_pos > 0
        let start_pos = 0
        continue
      else
        break
      endif
    endif

    
    let date_str = matchstr(line, date_pattern, start_pos)
    let date_end = match_start + len(date_str) - 1
    
    if cursor_col >= match_start + 1 && cursor_col <= date_end + 1 || start_pos == 0
      let matches = matchlist(date_str, '<\(\d\{4\}-\d\{2\}-\d\{2\}\)\s\+\(\a\{3\}\)\(.*\)>')
      let date_only = matches[1]
      let day_name = matches[2]
      let postfix = matches[3]  
      
      let [year, month, day] = split(date_only, '-')
      return [year, month, day, day_name, postfix, match_start, date_end, date_only]
    endif
    let start_pos = match_start + 1
  endwhile
  return []
endfunction

function! ShiftOrgDateDays(days)

  let line = getline('.')
  let cursor_col = col('.')

  let date_result = ExtractDateFromCurrentLine()
  if len(date_result) < 1
    echo "No date found near cursor" 
    return
  endif
  
  let [year, month, day, day_name, postfix, match_start, date_end, date_str] = date_result

  let current_timestamp = localtime()
  let forward_search = current_timestamp
  let backward_search = current_timestamp 
  let match_timestamp = ""
  let days_range_to_search = 365 * 20
  for i in range(days_range_to_search)
    if ConvertTimestampToDatePrefixStr(forward_search) == date_str
      let match_timestamp = forward_search
      break
    endif
    let forward_search = IncrementTimestampByDays(forward_search, 1)
    if ConvertTimestampToDatePrefixStr(backward_search) == date_str
      let match_timestamp = backward_search
      break
    endif
    let backward_search = IncrementTimestampByDays(backward_search, -1)
  endfor
  if len(match_timestamp) < 1
    echo "current date could not be converted to timestamp - could not find in next or past 20 years"
    return
  endif

  let new_timestamp = IncrementTimestampByDays(match_timestamp, a:days)
  let new_date = ConvertTimestampToDatePrefixStr(new_timestamp)
  let new_day = strftime('%a', new_timestamp)
  let new_date_tag = '<' . new_date . ' ' . new_day . postfix . '>'
  call UpdateDateOnCurrentLine(line, match_start, new_date_tag, date_end)
  
  call cursor(line('.'), cursor_col)

  
endfunction

autocmd FileType org nnoremap <buffer> <S-Right> :call ShiftOrgDateDays(1)<CR>
autocmd FileType org nnoremap <buffer> <S-Left> :call ShiftOrgDateDays(-1)<CR>

autocmd FileType org nnoremap <buffer> <Space>mds :call AddOrgDateWithType('SCHEDULED')<CR>
autocmd FileType org nnoremap <buffer> <Space>mdd :call AddOrgDateWithType('DEADLINE')<CR>




augroup OrgCalHighlight
  autocmd!
  autocmd BufNewFile,BufRead orgcal setfiletype orgcal
  autocmd FileType orgcal syntax match OrgCalTitle /^#.*$/
  autocmd FileType orgcal syntax match OrgCalTodo /TODO/
  autocmd FileType orgcal syntax match OrgCalDone /DONE/
  autocmd FileType orgcal syntax match OrgCalScheduled /SCHEDULED:/
  autocmd FileType orgcal syntax match OrgCalDeadline /DEADLINE/
  autocmd FileType orgcal syntax match OrgCalDate /<\d\{4}-\d\{2}-\d\{2}.*>/
  autocmd FileType orgcal syntax match OrgCalHiddenMeta /‡.\{-}‡/ conceal
  " Add priority pattern
  autocmd FileType orgcal syntax match OrgCalPriority /\[#[A-N]\]/
  
  autocmd FileType orgcal highlight OrgCalTitle ctermfg=Yellow guifg=#ffff00 gui=bold
  autocmd FileType orgcal highlight OrgCalTodo guifg=DarkOrange gui=bold
  autocmd FileType orgcal highlight OrgCalDone ctermfg=Green guifg=#66ff66
  autocmd FileType orgcal highlight OrgCalScheduled ctermfg=Cyan guifg=#6666ff gui=bold
  autocmd FileType orgcal highlight OrgCalDeadline  gui=bold
  autocmd FileType orgcal highlight OrgCalDate ctermfg=Blue guifg=#6699ff
  " Add priority highlighting
  autocmd FileType orgcal highlight OrgCalPriority guifg=DarkGreen gui=bold
  autocmd FileType orgcal highlight link OrgCalHiddenMeta Conceal
  
  autocmd FileType orgcal setlocal conceallevel=2
  autocmd FileType orgcal setlocal concealcursor=nvic
augroup END

function! s:OrgCalHiddenMeta(data)
  return "‡" . a:data . "‡"
endfunction

function! s:PopulateOrgCalendar(mode, current_timestamp)
  silent! normal! ggdG
  
  
  let line_num = 4

  if exists('g:orgcal_filepaths') == 0 
    echo "Cannot populate calendar: exp variable g:orgcal_filepaths to exist"
    return
  endif
  if empty(g:orgcal_filepaths)
    echo "Cannot populate calendar: exp variable g:orgcal_filepaths to not be empty"
    return
  endif

  let date_str_prefixes_to_load_into_calendar = GetOrderedDatePrefixesToLoadIntoCalendar(a:mode, a:current_timestamp)
  let upcoming_days_in_future_deadline_date_str_prefixes_to_load_into_calendar = GetUpcomingDeadlinesToLoadIntoCalendar(a:mode, a:current_timestamp)
  let headers_with_dates = []
  for org_file in g:orgcal_filepaths
    let file_lines = readfile(org_file)
    let org_file_name = fnamemodify(org_file, ":t")
    for h in ExtractHeadersWithDatesFromLines(file_lines, date_str_prefixes_to_load_into_calendar, upcoming_days_in_future_deadline_date_str_prefixes_to_load_into_calendar, org_file, org_file_name)
      call add(headers_with_dates, h)
    endfor
  endfor

  call append(0, "=============================================================================================")
  call append(1, "Press <Enter> on an entry to go to its file location")
  call append(2, "Press <Tab> on an entry to go to its file location in a split while keeping the calendar open")
  call append(3, "Press 'q' to close, 'r' to refresh")
  call append(4, "Press 'm' for month view")
  call append(5, "Press 'd' for default view")
  call append(6, "Press '[' for next calendar time window")
  call append(7, "Press ']' for previous calendar time window")
  call append(8, "=============================================================================================")
  let line_num = 9 
  let line_to_put_cursor_after_rendering = 0

  for ordered_prefix in date_str_prefixes_to_load_into_calendar
    let items_on_this_date = []
    
    for header_with_date in headers_with_dates
      let dates = header_with_date["dates"]
      for date in dates
        if ordered_prefix == date["dateStr"] 
          call add(items_on_this_date, header_with_date)
          break
        endif
      endfor
    endfor

    
    let [year, month, day] = split(ordered_prefix, '-')
    let timestamp = localtime()
    
    let days_diff = 0
    let current_ymd = strftime('%Y-%m-%d', timestamp)
    let [c_year, c_month, c_day] = split(current_ymd, '-')
    let days_diff += (year - c_year) * 365
    let days_diff += (month - c_month) * 30
    let days_diff += (day - c_day)
    let date_timestamp = timestamp + (days_diff * 86400)
    
    let day_name = strftime('%A', date_timestamp)
    let current_date = strftime('%Y-%m-%d')
    let this_iteration_is_for_current_date = current_date == ordered_prefix
    
    if this_iteration_is_for_current_date
      let line_to_put_cursor_after_rendering = line_num
    endif
    call append(line_num, day_name . " " . ordered_prefix)
    let line_num += 1

    "if len(items_on_this_date) < 1
    "  continue
    "endif
    
    let formatted_lines = []
    let formatted_lines_with_time_sorted = {0:[],1:[],2:[],3:[],4:[],5:[],6:[],7:[],8:[],9:[],10:[],11:[],12:[],13:[],14:[],15:[],16:[],17:[],18:[],19:[],20:[],21:[],22:[],23:[]}
    let formatted_lines_upcoming_deadline = []
    for h in items_on_this_date
      for date in h["dates"]
       if date["dateStr"] != ordered_prefix
         continue
       endif
       let time_str = get(date, "timeStr", "")
       if time_str != ""
         let hour_int = str2nr(matchstr(time_str, '^\d\{1,2}'))
         let formatted_line = "  " . h["orgFileName"] . " " . date["typeStr"] . " " . date["timeStr"] . " " . h["headerText"] . " " . h["hiddenMetaLink"]
         call add(formatted_lines_with_time_sorted[hour_int], formatted_line)
         continue
       endif
       let formatted_line = "  " . h["orgFileName"] . " " . date["typeStr"] . " " . h["headerText"] . " " . h["hiddenMetaLink"]
       call add(formatted_lines, formatted_line)
      endfor
    endfor

    for hour_int in range(24)
      for line in formatted_lines_with_time_sorted[hour_int]
        call append(line_num, line)
        let line_num += 1
      endfor
    endfor


    for line in formatted_lines
      call append(line_num, line)
      let line_num += 1
    endfor

    let upcoming_day_lines_map = {}
    let upcoming_deadline_days_in_future = GetUpcomingDeadlineDaysInFutureConfiguration()
    for i in range(upcoming_deadline_days_in_future)
      let upcoming_day_lines_map[i+1] = []
    endfor

    if this_iteration_is_for_current_date 
      for potential_upcoming_deadline_item in headers_with_dates
        let upcoming_days_deadline = potential_upcoming_deadline_item["upcomingDeadlineDays"]
        if upcoming_days_deadline > 0
          let formatted_line = "  " . potential_upcoming_deadline_item["orgFileName"] . " In " . upcoming_days_deadline . " d.: " . " " . potential_upcoming_deadline_item["headerText"] . " " . potential_upcoming_deadline_item["hiddenMetaLink"]
          call add(upcoming_day_lines_map[upcoming_days_deadline], {
            \ "line": formatted_line,
            \ "priority": potential_upcoming_deadline_item["priority"]
            \ })
        endif
      endfor
    endif

    for i in range(upcoming_deadline_days_in_future)
      let lines = upcoming_day_lines_map[i+1]
      " Sort by priority
      call sort(lines, function('s:ComparePriority'))
      for item in lines
        call append(line_num, item["line"])
        let line_num += 1
      endfor
    endfor
    
    call append(line_num, "")
    let line_num += 1
  endfor
  
  normal! ggj
  execute "normal! " . line_to_put_cursor_after_rendering . "j"
endfunction

function! GetUpcomingDeadlinesToLoadIntoCalendar(mode, current_timestamp)
  if a:mode != 'daily'  
    return {}
  endif
  let act_current_time = localtime()
  let current_render_is_not_for_present_day = act_current_time + 10 < act_current_time || act_current_time - 10 > act_current_time
  if current_render_is_not_for_present_day
    return {}
  endif
  let days_in_future_upcoming_deadline = GetUpcomingDeadlineDaysInFutureConfiguration()
  let date_prefixes = GetDatePrefixesByRangeFromToday(-1, days_in_future_upcoming_deadline, a:current_timestamp)

  let day_prefix_map = {}
  for i in range(len(date_prefixes))
    let day_prefix_map[i+1] = date_prefixes[i]
  endfor
  return day_prefix_map
endfunction

function! GetUpcomingDeadlineDaysInFutureConfiguration()
    return GetGlobalOrDefault('days_in_future_upcoming_deadline_to_show_in_daily_mode', 18)
endfunction

function! GetGlobalOrDefault(global_variable_name, default)
  let full_var_name = 'g:' . a:global_variable_name
  
  if exists(full_var_name)
    return eval(full_var_name)
  else
    return a:default
  endif
endfunction

function! ExtractHeadersWithDatesFromLines(lines, date_str_prefixes_to_load_into_calendar, upcoming_days_in_future_deadline_date_str_prefixes_to_load_into_calendar, org_file, org_file_name)
  let line_num = 0
  
  let in_todo_item = 0
  let todo_line_num = 0

  let response = []
  
  let lines_to_iterate = len(a:lines) - 1 
  for i in range(lines_to_iterate)
    let line = a:lines[i]

    " not using LineIsOrgHeader since this boosts performance and saves a stack pop/push per line
    if line[0] !=# '*'
      continue
    endif
    
    let next_line = a:lines[i+1]
    let dates_with_types = GetDatesWithTypesFromLine(next_line)
    if len(dates_with_types) < 1
      continue
    endif

    let dates_with_types_within_range = []
    let upcoming_deadline_days_in_future = 0
    for date in dates_with_types
      for valid_date_prefix in a:date_str_prefixes_to_load_into_calendar
        if date["dateStr"] == valid_date_prefix
          call add(dates_with_types_within_range, date)
          break
        endif
      endfor
      if date["typeStr"] == "DEADLINE"
        for days_in_future in keys(a:upcoming_days_in_future_deadline_date_str_prefixes_to_load_into_calendar)
          if date["dateStr"] == a:upcoming_days_in_future_deadline_date_str_prefixes_to_load_into_calendar[days_in_future]
            let upcoming_deadline_days_in_future = days_in_future
            break
          endif
        endfor
      endif
    endfor

    if len(dates_with_types_within_range) < 1 && upcoming_deadline_days_in_future < 1
      continue
    endif

    let headline = GetOrgHeaderTextFromLine(line)
    let header_line_col = i + 1  

    " Extract priority
    let priority = s:ExtractPriority(line)
    
    let headerDate = {
      \ "headerText": headline,
      \ "dates": dates_with_types_within_range,
      \ "hiddenMetaLink": s:OrgCalHiddenMeta(a:org_file . "|" . header_line_col),
      \ "orgFileName": a:org_file_name,
      \ "upcomingDeadlineDays": upcoming_deadline_days_in_future,
      \ "priority": priority
      \ }
    call add(response, headerDate)
  endfor
  return response
endfunction

function! GetDatePrefixesByRangeFromToday(amount_days_in_past_from_current_date, amount_days_in_future_from_current_date, current_timestamp)
    
    let dates = []
    
    for day_offset in range(-a:amount_days_in_past_from_current_date, a:amount_days_in_future_from_current_date)
      let date_timestamp = IncrementTimestampByDays(a:current_timestamp, day_offset)
      let date_str = ConvertTimestampToDatePrefixStr(date_timestamp)
      call add(dates, date_str)
    endfor
    
    return dates
endfunction

function! ConvertTimestampToDatePrefixStr(timestamp)
  return strftime('%Y-%m-%d', a:timestamp)
endfunction

function! IncrementTimestampByDays(timestamp, days)
  return a:timestamp + (a:days * 86400)  " 86400 seconds in a day
endfunction

function! GetOrderedDatePrefixesToLoadIntoCalendar(mode, relative_current_timestamp)
  if a:mode ==# 'daily'
    let days_in_past = 1
    if exists('g:daily_mode_days_in_past')
      let days_in_past = g:daily_mode_days_in_past
    endif
    let days_in_future = 1
    if exists('g:daily_mode_days_in_future')
      let days_in_future = g:daily_mode_days_in_future
    endif
    return GetDatePrefixesByRangeFromToday(days_in_past,days_in_future, a:relative_current_timestamp)
  elseif a:mode ==# 'monthly' 
    let today = a:relative_current_timestamp
    let current_time = today
    let year_month_prefix_match = strftime('%Y-%m', current_time)
    let prefixes = []
    let prefix = ConvertTimestampToDatePrefixStr(current_time)
    while StartsWith(year_month_prefix_match, prefix)
      call insert(prefixes, prefix)
      let current_time = IncrementTimestampByDays(current_time, -1)
      let prefix = ConvertTimestampToDatePrefixStr(current_time)
    endwhile
    let current_time = IncrementTimestampByDays(today, +1)
    let prefix = ConvertTimestampToDatePrefixStr(current_time)
    while StartsWith(year_month_prefix_match, prefix)
      call add(prefixes, prefix)
      let current_time = IncrementTimestampByDays(current_time, 1)
      let prefix = ConvertTimestampToDatePrefixStr(current_time)
    endwhile
    return prefixes
  endif
  
endfunction

function! StartsWith(to_match, str)
  return a:str =~# '^' . a:to_match
endfunction

function! GetDatesWithTypesFromLine(line)
  let results = []
  let line = a:line
  
  let date_types = ['DEADLINE', 'SCHEDULED']
  let date_pattern = '<\(\d\{4}-\d\{2\}-\d\{2\}\)\s\+\w\{2,3\}\(\s\+\(\d\{1,2}:\d\{2\}\(-\d\{1,2}:\d\{2\}\)\?\)\)\?'
  
  for date_type in date_types
    let start_pos = 0
    
    while 1
      let type_pos = match(line, date_type . ':', start_pos)
      if type_pos == -1
        break
      endif
      
      let date_pos = match(line, date_pattern, type_pos)
      
      if date_pos != -1 && date_pos - type_pos < 20
        let date_match = matchlist(line, date_pattern, date_pos)
        if len(date_match) > 1
          let result = {"dateStr": date_match[1], "typeStr": date_type}
          
          if len(date_match) > 3 && date_match[3] != ''
            let result["timeStr"] = date_match[3]
          endif
          
          call add(results, result)
        endif
      endif
      
      let start_pos = type_pos + len(date_type)
    endwhile
  endfor
  
  return results
endfunction

function! GetOrgHeaderTextFromLine(line)
  return substitute(a:line,  '^\*\+\s', '', '')
endfunction

function! s:OrgCalOpenEntry()
  let line = getline('.')
  
  let meta_pattern = '‡\(.\{-}\)‡'
  let matches = matchlist(line, meta_pattern)
  
  if len(matches) > 1
    let file_info = split(matches[1], '|')
    if len(file_info) >= 2
      let file_path = file_info[0]
      let line_number = file_info[1]
      
      execute 'edit +' . line_number . ' ' . file_path
    endif
  endif
endfunction

function! s:OrgCalOpenEntryVSplit()
  let line = getline('.')
  
  let meta_pattern = '‡\(.\{-}\)‡'
  let matches = matchlist(line, meta_pattern)
  
  if len(matches) > 1
    let file_info = split(matches[1], '|')
    if len(file_info) >= 2
      let file_path = file_info[0]
      let line_number = file_info[1]
      
      let buf_nr = bufnr(file_path)
      if buf_nr > 0
        let win_id = bufwinid(buf_nr)
        if win_id != -1
          call win_gotoid(win_id)
          execute line_number
          normal! z.
          return
        endif
      endif
      
      execute 'vsplit +' . line_number . ' ' . file_path
      normal! z.
    endif
  endif
endfunction

function! s:RefreshOrgCalendar(mode, current_timestamp)
  let g:orgcal_current_mode = a:mode
  setlocal modifiable
  call s:PopulateOrgCalendar(a:mode, a:current_timestamp)
  setlocal nomodifiable
endfunction

function! s:MoveCalendarTimeWindowStepsAndRefresh(steps)
  let mode = g:orgcal_current_mode 
  if mode == "daily"
    let g:orgcal_relative_now = IncrementTimestampByDays(g:orgcal_relative_now, a:steps)
  elseif mode == "monthly"
    let curr_relative_month = strftime("%m", g:orgcal_relative_now)
    let date_incremented = IncrementTimestampByDays(g:orgcal_relative_now,a:steps)
    while strftime("%m", date_incremented) == curr_relative_month
      
      let date_incremented = IncrementTimestampByDays(date_incremented,a:steps)
    endwhile
    let g:orgcal_relative_now = date_incremented
  endif
  call s:RefreshOrgCalendar(mode,g:orgcal_relative_now)
endfunction

function! s:ReloadOrgCalendar()
  let g:orgcal_relative_now = localtime()
  call s:RefreshOrgCalendar('daily', localtime())
endfunction

function! s:QuitOrgCalendar()
  let g:orgcal_relative_now = localtime()
  bwipeout!
endfunction

function! s:OpenOrgCalendar(mode)
  let buf_nr = bufnr('orgcal')
  let g:orgcal_current_mode = a:mode

  let win_id = bufwinid(buf_nr)
  let buffer_already_exists = buf_nr > 0
  let window_is_open_in_editor = win_id != -1
  if buffer_already_exists && window_is_open_in_editor
    call win_gotoid(win_id)
    return
  elseif buffer_already_exists
    execute 'e orgcal'
    return
  else
    enew
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nowrap
    setlocal nonumber
    setlocal nofoldenable
    let g:orgcal_relative_now = localtime()
    
    execute 'file orgcal'
    setlocal filetype=orgcal
  endif
  
  setlocal modifiable
  
  call s:PopulateOrgCalendar(a:mode, g:orgcal_relative_now)
  
  nnoremap <buffer> <CR> :call <SID>OrgCalOpenEntry()<CR>
  nnoremap <buffer> <Tab> :call <SID>OrgCalOpenEntryVSplit()<CR>
  nnoremap <buffer> q :call <SID>QuitOrgCalendar()<CR>
  nnoremap <buffer> r :call <SID>ReloadOrgCalendar()<CR>
  nnoremap <buffer> m :call <SID>RefreshOrgCalendar('monthly', localtime())<CR>
  nnoremap <buffer> d :call <SID>RefreshOrgCalendar('daily', localtime())<CR>
  nnoremap <buffer> [ :call <SID>MoveCalendarTimeWindowStepsAndRefresh(1)<CR>
  nnoremap <buffer> ] :call <SID>MoveCalendarTimeWindowStepsAndRefresh(-1)<CR>
  
  setlocal nomodifiable
endfunction

command! -nargs=0 OrgCal call s:OpenOrgCalendar('daily')
nnoremap <C-c> :OrgCal<CR>

let s:fold_structure = []
let s:line_to_fold_map = {}

function! s:RenderFolds(folds, current_line_nr)
  let scoped_current_line_nr = a:current_line_nr
  let line_to_put_cursor = -1
  for fold in a:folds
    let scoped_current_line_nr += 1
    let isUnfolded = fold["isUnfolded"]
    let children = fold["children"]
    let should_display_dots = isUnfolded == 0 && len(children) > 0
    let text = fold["headerText"]
    if should_display_dots
      let text = text . " [..]"
    endif
    call append(scoped_current_line_nr, text)
    
    " Store mapping from line number to fold object
    let s:line_to_fold_map[scoped_current_line_nr + 1] = fold
    
    if fold["isCursorFocus"] == 1
      let line_to_put_cursor = scoped_current_line_nr
    endif
    if isUnfolded == 0
      continue
    endif
    let response = s:RenderFolds(children, scoped_current_line_nr)
    let scoped_current_line_nr = response["updatedCurrentLineNr"]
    if response["lineToPutCursor"] > -1
      let line_to_put_cursor = response["lineToPutCursor"]
    endif
  endfor
  return { "updatedCurrentLineNr": scoped_current_line_nr, "lineToPutCursor": line_to_put_cursor }
endfunction

function! s:PopulateOrgFold(source_filepath, source_line_nr, source_buffer_contents)
  let s:line_to_fold_map = {}  " Reset the mapping
  let s:fold_structure = ExtractFoldsFromLines(a:source_buffer_contents, a:source_line_nr-1)
  
  " Start rendering from line 6 (after the header)
  let response = s:RenderFolds(s:fold_structure, 6)
  let line_to_put_cursor = response["lineToPutCursor"]
  normal! gg
  execute "normal! " . line_to_put_cursor . "j"
endfunction

function! GetAsterixCountFromHeaderLine(line)
    let c = a:line[0]
    let header_asterix_count = 0

    while c == '*' && header_asterix_count < len(a:line)
      let header_asterix_count += 1
      let c = a:line[header_asterix_count]
    endwhile
    return header_asterix_count
endfunction

function! ExtractFoldsFromLines(source_buffer_contents, cursor_line_nr)
  let headers_at_root = []
  let current_level = 0
  let line_nr = -1
  let last_fold  = {}
  for line in a:source_buffer_contents
    let line_nr += 1
    if len(line) == 0
      continue
    endif
    if line[0] != '*'
      continue
    endif

    let header_asterix_count = GetAsterixCountFromHeaderLine(line)
  
    let fold_obj = {
    \ "headerText": line,
    \ "asterixCount": header_asterix_count,
    \ "lineNr": line_nr,
    \ "children": [],
    \ "parent": {},
    \ "isCursorFocus": 0,
    \ "isUnfolded": 0
    \ }
    let this_fold_matches_cursor_placement = line_nr == a:cursor_line_nr
    let last_fold_matches_cursor_placement = line_nr > a:cursor_line_nr && empty(last_fold) == 0 && last_fold["lineNr"] <= a:cursor_line_nr 
    if this_fold_matches_cursor_placement || last_fold_matches_cursor_placement
      let curr = this_fold_matches_cursor_placement ? fold_obj : last_fold
      let curr["isCursorFocus"] = 1
      let curr = curr["parent"]
      while empty(curr) == 0
        let curr["isUnfolded"] = 1
        let curr = curr["parent"]
      endwhile
    endif
  
    while empty(last_fold) == 0 && last_fold["asterixCount"] >= header_asterix_count 
      let last_fold = last_fold["parent"]
    endwhile
  
    if empty(last_fold) 
      call add(headers_at_root, fold_obj)
    else
      let fold_obj["parent"] = last_fold
      call add(last_fold["children"], fold_obj)
    endif
  
    let last_fold = fold_obj
  
  endfor

  return headers_at_root
endfunction

function! s:OpenOrgFold()
  let s:source_file = expand('%:p')
  let s:source_line = line('.')
  let s:source_buffer_contents = getline(1, '$')
  
  let buf_nr = bufnr('orgfold')
  let win_id = bufwinid(buf_nr)
  let buffer_already_exists = buf_nr > 0
  let window_is_open_in_editor = win_id != -1
  
  if buffer_already_exists && window_is_open_in_editor
    call win_gotoid(win_id)
  elseif buffer_already_exists
    execute 'buffer ' . buf_nr
  else
    enew
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nowrap
    setlocal nonumber
    setlocal nofoldenable
    
    execute 'file orgfold'
    setlocal filetype=orgfold
    
    " Set up syntax highlighting for the orgfold buffer - improved patterns
    syntax match OrgFoldHeader /^\*\+\s.*\ze\s\[\.\.\]$\|^\*\+\s.*\([^\.]\)$/
    syntax match OrgFoldFoldDots /\[\.\.\]/ contained
    syntax match OrgFoldFoldBracket /\[\|\]/ contained containedin=OrgFoldFoldDots
    syntax match OrgFoldCollapsed /\s\[\.\.\]$/ contains=OrgFoldFoldDots
    
    highlight OrgFoldHeader gui=bold guifg=DarkOrange
    highlight OrgFoldFoldDots gui=bold guifg=DarkOrange
    highlight OrgFoldFoldBracket gui=bold guifg=Gray40
  endif
  
  " Always clear and repopulate
  setlocal modifiable
  silent! normal! ggdG
  
  " Add header with key shortcuts
  call append(0, "=============================================================================================")
  call append(1, "OrgFold View")
  call append(2, "Press <Enter> on an entry to go to its location")
  call append(3, "Press <Tab> to expand/collapse a section")
  call append(4, "Press 'q' to close")
  call append(5, "=============================================================================================")
  
  call s:PopulateOrgFold(s:source_file, s:source_line, s:source_buffer_contents)
  
  nnoremap <buffer> <CR> :call <SID>OrgFoldEnter()<CR>
  nnoremap <buffer> <Tab> :call <SID>OrgFoldToggle()<CR>
  nnoremap <buffer> q :bwipeout!<CR>
  
  setlocal nomodifiable
endfunction

function! s:OrgFoldToggle()
  let current_line = line('.')
  if has_key(s:line_to_fold_map, current_line)
    let fold = s:line_to_fold_map[current_line]
    " Toggle the fold state
    let fold["isUnfolded"] = !fold["isUnfolded"]
    
    " Redraw the buffer with updated fold state
    setlocal modifiable
    silent! normal! ggdG
    call s:RerenderFolds()
    setlocal nomodifiable
    
    " Return to the same line position
    execute "normal! " . current_line . "G"
  endif
endfunction

function! s:ShowParentStructure()
  let current_line = line('.')
  if has_key(s:line_to_fold_map, current_line)
    let fold = s:line_to_fold_map[current_line]
    let hierarchy = []
    
    " Add the current fold's header text
    let header_text = substitute(fold["headerText"], '^\*\+\s\+', '', '')
    call add(hierarchy, header_text)
    
    " Add all parents
    let parent = fold["parent"]
    while !empty(parent)
      let parent_text = substitute(parent["headerText"], '^\*\+\s\+', '', '')
      call insert(hierarchy, parent_text)
      let parent = parent["parent"]
    endwhile
    
    " Display the hierarchy in the command line
    echo join(hierarchy, ' / ')
  endif
endfunction

function! s:RerenderFolds()
  " Clear the line mapping before rerendering
  let s:line_to_fold_map = {}
  let response = s:RenderFolds(s:fold_structure, 0)
endfunction

function! s:OrgFoldEnter()
  let current_line = line('.')
  
  if has_key(s:line_to_fold_map, current_line)
    let fold = s:line_to_fold_map[current_line]
    let target_line_nr = fold["lineNr"] + 1  " +1 because Vim line numbers start at 1 but indices start at 0
    
    " Close the orgfold buffer
    bwipeout!
    
    " Navigate to the original file and position
    execute "edit " . s:source_file
    execute "normal! " . target_line_nr . "G"
    normal! z.  " Center the view on the current line
  endif
endfunction

" Add autocmd to show parent structure when cursor moves in orgfold buffer
augroup OrgFoldParentStructure
  autocmd!
  autocmd CursorMoved orgfold call s:ShowParentStructure()
augroup END

command! -nargs=0 OrgFold call s:OpenOrgFold()
nnoremap <S-tab> :OrgFold<CR>

augroup OrgStateHighlight
  autocmd!
  autocmd BufNewFile,BufRead orgstate setfiletype orgstate
  autocmd FileType orgstate syntax match OrgStateHeader /^\*.*$/
  autocmd FileType orgstate syntax match OrgStateTodo /TODO/
  autocmd FileType orgstate syntax match OrgStateProjTag /PROJ/
  autocmd FileType orgstate syntax match OrgStateHighPriority /\[#[A-C]\]/
  autocmd FileType orgstate syntax match OrgStateMediumPriority /\[#[D-H]\]/
  autocmd FileType orgstate syntax match OrgStateLowPriority /\[#[I-N]\]/
  autocmd FileType orgstate syntax match OrgStateHiddenMeta /‡.\{-}‡/ conceal
  
  autocmd FileType orgstate highlight OrgStateHeader ctermfg=Yellow guifg=#ffff00 gui=bold
  autocmd FileType orgstate highlight OrgStateTodo guifg=DarkOrange gui=bold
  autocmd FileType orgstate highlight OrgStateProjTag guifg=DarkOrange gui=bold
  autocmd FileType orgstate syntax match OrgStatePriority /\[#[A-N]\]/ containedin=OrgStateHighPriority,OrgStateMediumPriority,OrgStateLowPriority
  autocmd FileType orgstate highlight OrgStatePriority guifg=DarkGreen gui=bold
  
  autocmd FileType orgstate highlight link OrgStateHiddenMeta Conceal
  
  autocmd FileType orgstate setlocal conceallevel=2
  autocmd FileType orgstate setlocal concealcursor=nvic
augroup END

function! s:PopulateOrgState(state)
  silent! normal! ggdG
  
  if exists('g:orgcal_filepaths') == 0 
    echo "Cannot populate state view: expected variable g:orgcal_filepaths to exist"
    return
  endif
  if empty(g:orgcal_filepaths)
    echo "Cannot populate state view: expected variable g:orgcal_filepaths to not be empty"
    return
  endif
  
  let headers_with_state = []
  
  for org_file in g:orgcal_filepaths
    let file_lines = readfile(org_file)
    let org_file_name = fnamemodify(org_file, ":t")
    
    let line_num = 0
    for line in file_lines
      let line_num += 1
      
      " Check if line starts with * and contains the state
      if line =~# '^\*\+\s' && line =~# '^\*\+\s\+' . a:state
        call add(headers_with_state, {
          \ "headerText": line,
          \ "filePath": org_file,
          \ "fileName": org_file_name,
          \ "lineNum": line_num,
          \ "priority": s:ExtractPriority(line)
        \ })
      endif
    endfor
  endfor
  
  " Sort headers by priority
  call sort(headers_with_state, function('s:ComparePriority'))
  
  " Display headers
  call append(0, "=============================================================================================")
  call append(1, "State: " . a:state)
  call append(2, "Press <Enter> on an entry to go to its file location")
  call append(3, "Press 'q' to close")
  call append(4, "=============================================================================================")
  
  let line_num = 5
  for header in headers_with_state
    let display_line = header["fileName"] . ": " . header["headerText"] . " " . s:OrgCalHiddenMeta(header["filePath"] . "|" . header["lineNum"])
    call append(line_num, display_line)
    let line_num += 1
  endfor
endfunction

function! s:ExtractPriority(line)
  let priority_match = matchlist(a:line, '\[#\([A-N]\)\]')
  if len(priority_match) > 1
    return priority_match[1]
  endif
  return "Z"  " Default lowest priority
endfunction

function! s:ComparePriority(i1, i2)
  return a:i1["priority"] == a:i2["priority"] ? 0 : a:i1["priority"] > a:i2["priority"] ? 1 : -1
endfunction

function! s:OrgStateOpenEntry()
  let line = getline('.')
  
  let meta_pattern = '‡\(.\{-}\)‡'
  let matches = matchlist(line, meta_pattern)
  
  if len(matches) > 1
    let file_info = split(matches[1], '|')
    if len(file_info) >= 2
      let file_path = file_info[0]
      let line_number = file_info[1]
      
      execute 'edit +' . line_number . ' ' . file_path
    endif
  endif
endfunction

function! s:OpenOrgState(...)
  let state = a:0 > 0 ? a:1 : "PROJ"
  
  let buf_nr = bufnr('orgstate')
  let win_id = bufwinid(buf_nr)
  let buffer_already_exists = buf_nr > 0
  let window_is_open_in_editor = win_id != -1
  
  if buffer_already_exists && window_is_open_in_editor
    call win_gotoid(win_id)
  elseif buffer_already_exists
    execute 'buffer ' . buf_nr
  else
    enew
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nowrap
    setlocal nonumber
    setlocal nofoldenable
    
    execute 'file orgstate'
    setlocal filetype=orgstate
  endif
  
  setlocal modifiable
  call s:PopulateOrgState(state)
  
  nnoremap <buffer> <CR> :call <SID>OrgStateOpenEntry()<CR>
  nnoremap <buffer> q :bwipeout!<CR>
  
  setlocal nomodifiable
  
  " Position cursor at the first entry
  normal! 6G
endfunction

command! -nargs=? OrgState call s:OpenOrgState(<f-args>)

" Generate help tags
let s:path = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
execute 'helptags ' . s:path . '/doc'

" Add after the file's existing functions

function! GetPriorityFromLine(line)
  let priority_match = matchlist(a:line, '\[#\([A-N]\)\]')
  if len(priority_match) > 1
    return priority_match[1]
  endif
  return ""
endfunction

function! ShiftPriority(direction)
  let line = getline('.')
  if !LineIsOrgHeader(line)
    echo "Not on a header line"
    return
  endif
  
  let current_priority = GetPriorityFromLine(line)
  let new_priority = ""
  
  if current_priority == ""
    " No priority exists yet
    if a:direction == "up"
      let new_priority = "A"
    else
      let new_priority = "N"
    endif
  else
    " Priority exists, shift it
    let ascii_val = char2nr(current_priority)
    if a:direction == "up"
      " Shift up (A is highest, so decrease ASCII value)
      if ascii_val > 65  " 'A' in ASCII
        let new_priority = nr2char(ascii_val - 1)
      else
        let new_priority = "A"  " Already at highest
      endif
    else
      " Shift down (increase ASCII value)
      if ascii_val < 78  " 'N' in ASCII
        let new_priority = nr2char(ascii_val + 1)
      else
        let new_priority = "N"  " Already at lowest
      endif
    endif
  endif
  
  " Apply the new priority
  if current_priority == ""
    " Insert new priority after TODO/DONE/etc word
    let pattern = '^\(\*\+\s\+\w\+\s\+\)'
    let replacement = '\1[#' . new_priority . '] '
    let new_line = substitute(line, pattern, replacement, '')
    
    " If no state (TODO/DONE) exists, insert after stars
    if new_line == line
      let pattern = '^\(\*\+\s\+\)'
      let replacement = '\1[#' . new_priority . '] '
      let new_line = substitute(line, pattern, replacement, '')
    endif
  else
    " Replace existing priority
    let new_line = substitute(line, '\[#' . current_priority . '\]', '[#' . new_priority . ']', '')
  endif
  
  call setline('.', new_line)
endfunction

" Add key mappings for priority shifting
autocmd FileType org nnoremap <buffer> <S-Up> :call ShiftPriority("up")<CR>
autocmd FileType org nnoremap <buffer> <S-Down> :call ShiftPriority("down")<CR>