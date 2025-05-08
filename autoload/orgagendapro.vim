augroup OrgHighlights
  autocmd!
  " checklist highlight
  autocmd FileType org syntax match OrgCompletedItem /^.*\[X\].*$/  
  autocmd FileType org highlight OrgCompletedItem ctermfg=DarkGray guifg=Gray40
  
  autocmd FileType org syntax match OrgUncheckedCheckbox /\[ \]/ containedin=ALL
  autocmd FileType org syntax match OrgUncheckedCheckbox /\[-\]/ containedin=ALL
  autocmd FileType org highlight OrgUncheckedCheckbox  guifg=DarkOrange
  
  " Bold headers - use central color or inherit
  autocmd FileType org syntax match OrgHeader /^\*.*$/
  autocmd FileType org highlight OrgHeader term=bold cterm=bold gui=bold guifg=DarkOrange

  " DONE headers - always grayed out
  autocmd FileType org syntax match OrgDoneHeader /^\*\+\s\+DONE\s.*$/
  autocmd FileType org highlight OrgDoneHeader ctermfg=DarkGray guifg=Gray40 term=bold cterm=bold gui=bold

  " Bold date things - use central color or inherit
  autocmd FileType org syntax match OrgScheduled /SCHEDULED:/
  if exists('g:org_highlight_foreground') && g:org_highlight_foreground != ''
    autocmd FileType org execute "highlight OrgScheduled term=bold cterm=bold gui=bold guifg=" . g:org_highlight_foreground
  else
    " Use current foreground color with bold
    autocmd FileType org highlight OrgScheduled term=bold cterm=bold gui=bold
  endif
  
  autocmd FileType org syntax match OrgDeadline /DEADLINE:/
  if exists('g:org_highlight_foreground') && g:org_highlight_foreground != ''
    autocmd FileType org execute "highlight OrgDeadline term=bold cterm=bold gui=bold guifg=" . g:org_highlight_foreground
  else
    " Use current foreground color with bold
    autocmd FileType org highlight OrgDeadline term=bold cterm=bold gui=bold
  endif
  
  " Add highlight for CLOSED timestamp
  autocmd FileType org syntax match OrgClosed /CLOSED:/
  autocmd FileType org highlight OrgClosed term=bold cterm=bold gui=bold ctermfg=DarkGray guifg=Gray40
  
  " Highlight and underline URLs
  autocmd FileType org syntax match OrgHyperlink /https\?:\/\/[A-Za-z0-9_\/.#?&=~-]\+/
  autocmd FileType org highlight OrgHyperlink term=underline cterm=underline gui=underline 
augroup END

" Enable filetype detection for org files
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
  
  " Format the date text with the type
  let formatted_date_text = a:date_type . ": " . a:date_text
  
  if next_line =~# '^\s*$' || next_line_num > line('$')
    " Next line is empty or doesn't exist - insert date on new line
    call append(a:line_num, "  " . formatted_date_text)
    return next_line_num
  elseif next_line =~# '<\d\{4\}-\d\{2\}-\d\{2\}'
    " Next line contains a date pattern - prefix with our date
    call setline(next_line_num, "  " . formatted_date_text . " " . next_line)
    return next_line_num
  else
    " Next line has content but no date - insert date on new line
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
  
  " Get current date in required format
  let today = strftime('%Y-%m-%d %a')
  let date_text = "<" . today . ">"
  
  call AddOrgDateText(line('.'), a:date_type, date_text)
endfunction

function! HandleOrgEnterKey()
  let line = getline('.')

  if LineIsOrgHeader(line)
    " Extract the header text without the asterisks
    let header_text = substitute(line, '^\*\+\s*', '', '')
    
    " Check for recurring tasks (has a scheduled/deadline date with +Nd pattern)
    let next_line_num = line('.') + 1
    let next_line = getline(next_line_num)
    let recurring_pattern = '<\d\{4\}-\d\{2\}-\d\{2\}\s\+\w\{3\}\(\s\+\d\{1,2}:\d\{2\}\(-\d\{1,2}:\d\{2\}\)\?\)\?\s\+\(+\d\+[dwmy]\)'

    if next_line =~# recurring_pattern && header_text =~# '^TODO\s'
      " This is a recurring task - extract the recurring info
      let recurring_match = matchlist(next_line, recurring_pattern)
      let recurring_spec = recurring_match[3]  " e.g., '+1d', '+2w', '+3m', '+1y'
      let increment = str2nr(recurring_spec[1:-2])  " remove '+' and unit, convert to number
      let unit = recurring_spec[-1:]  " get 'd', 'w', 'm', or 'y'

      " Find the position of the date tag in the next line
      let date_tag_pos = match(next_line, '<\d\{4\}-\d\{2\}-\d\{2\}')
      
      " Update the date in the next line
      call cursor(next_line_num, date_tag_pos + 1)  " Position cursor at the start of the date tag
      
      if unit ==# 'd'
        call ShiftOrgDateDays(increment)
      elseif unit ==# 'w'
        call ShiftOrgDateDays(increment * 7)
      elseif unit ==# 'm'
        call ShiftOrgDateMonths(increment)
      elseif unit ==# 'y'
        call ShiftOrgDateYears(increment)
      endif
      
      " Return to the header line
      call cursor(line('.') - 1, col('.'))
      return
    endif
    
    " Non-recurring task - handle normal TODO/DONE toggle
    if header_text =~# '^TODO\s'
      " Change TODO to DONE
      let new_header = substitute(line, 'TODO', 'DONE', '')
      call setline('.', new_header)
      
      " Add CLOSED timestamp with current date and time
      let current_datetime = strftime('[%Y-%m-%d %a %H:%M]')
      call AddOrgDateText(line('.'), 'CLOSED', current_datetime)
      return
    elseif header_text =~# '^DONE\s'
      " Change DONE to TODO
      let new_header = substitute(line, 'DONE', 'TODO', '')
      call setline('.', new_header)
      
      return
    endif
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
    
    " If cursor is within URL boundaries
    if cursor_col >= url_start + 1 && cursor_col <= url_end + 1
      let url = strpart(line, url_start, url_end - url_start + 1)
      call system('start "" "' . url . '"')
      return
    endif
  endif
endfunction
autocmd FileType org nnoremap <buffer> <CR> :call HandleOrgEnterKey()<CR>

function! HandleOrgCtrlEnterKey()
  let line = getline('.')
  let checkbox_pattern = '^\(\s*\)- \[\s*[X ]\s*\]'
  
  if match(line, checkbox_pattern) >= 0
    let indentation = matchstr(line, '^\s*')
    
    let new_line = indentation . '- [ ] '
    
    call append(line('.'), new_line)
    
    normal! j$
    startinsert!

    return
  endif
  
  " Default behavior: just insert a new line
  execute "normal! o"
endfunction

function! HandleOrgCtrlNKey()
    " No active search, set search pattern to find unchecked boxes
    let @/ = '\[ \]'
    " Jump to first match
    normal! n
endfunction
autocmd FileType org nnoremap <buffer> <C-CR> :call HandleOrgCtrlEnterKey()<CR>
autocmd FileType org nnoremap <buffer> <C-n> :call HandleOrgCtrlNKey()<CR>

" Narrow view toggle for org mode
let g:narrow_view_active = 0

function! DisableNarrow()
    if g:narrow_view_active == 0
      return
    endif
    normal! zR
    let g:narrow_view_active = 0
endfunction

function! EnableNarrow()
    " Store current position
    let l:current_line = line('.')
    let l:current_col = col('.')
    
    " Find current section header by searching backwards for a line starting with *
    let l:current_header = l:current_line
    let l:current_level = 0
    
    while l:current_header > 0
        " Save current position
        let l:old_pos = getpos('.')
        " Move cursor to the potential header line
        call cursor(l:current_header, 1)
        
        if LineIsOrgHeader(getline('.'))
            " Count number of asterisks in current header
            let l:current_level = GetCurrentLineOrgHeaderLevel()
            " Restore cursor position
            call setpos('.', l:old_pos)
            break
        endif
        
        " Restore cursor position
        call setpos('.', l:old_pos)
        let l:current_header -= 1
    endwhile
    
    " If no header found, use line 1
    if l:current_header == 0
        let l:current_header = 1
        let l:current_level = 1
    endif
    
    " Find next section header by searching forward
    " Only match headers with the same or fewer asterisks
    let l:next_header = l:current_line + 1
    let l:last_line = line('$')
    
    while l:next_header <= l:last_line
        let l:line = getline(l:next_header)
        if l:line =~# '^\*'
            " Count asterisks in the next header
            let l:next_level = len(matchstr(l:line, '^\*\+'))
            " Only consider this a matching header if it has same or fewer asterisks
            if l:next_level <= l:current_level
                break
            endif
        endif
        let l:next_header += 1
    endwhile
    
    " If no next header found, use EOF
    if l:next_header > l:last_line
        let l:next_header = l:last_line + 1
    endif
    
    " Create folds for everything except current section
    normal! zE  " Clear all folds
    
    " Fold everything before current header
    if l:current_header > 1
        execute "1," . (l:current_header - 1) . "fold"
    endif
    
    " Fold everything after next header - 1
    if l:next_header <= l:last_line
        execute l:next_header . "," . l:last_line . "fold"
    endif

    " Move cursor back to original position
    call cursor(l:current_line, l:current_col)
    
    let g:narrow_view_active = 1
    echo "Narrowed view to current section (level " . l:current_level . ")"
endfunction
autocmd FileType org nnoremap <buffer> <Space>msn :call EnableNarrow()<CR>
autocmd FileType org nnoremap <buffer> <Space>msN :call DisableNarrow()<CR>

function! ShiftOrgDateYears(years)
  let line = getline('.')
  let cursor_col = col('.')
  let [year, month, day, day_name, postfix, match_start, date_end] = ExtractDateFromCurrentLine()
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
    Error "Invalid months: must be non-negative"
  endif

  let [year, month, day, day_name, postfix, match_start, date_end] = ExtractDateFromCurrentLine()
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
      " If no match found starting from cursor, try from beginning of line
      if start_pos > 0
        let start_pos = 0
        continue
      else
        break
      endif
    endif

    
    let date_str = matchstr(line, date_pattern, start_pos)
    let date_end = match_start + len(date_str) - 1
    
    " Check if cursor is inside the date tag or if we're searching the whole line
    if cursor_col >= match_start + 1 && cursor_col <= date_end + 1 || start_pos == 0
      " Extract components from the matched date
      let matches = matchlist(date_str, '<\(\d\{4\}-\d\{2\}-\d\{2\}\)\s\+\(\a\{3\}\)\(.*\)>')
      let date_only = matches[1]
      let day_name = matches[2]
      let postfix = matches[3]  " This captures time, recurring pattern, or any other postfix
      
      " Convert date string to seconds since epoch
      let [year, month, day] = split(date_only, '-')
      return [year, month, day, day_name, postfix, match_start, date_end]
    endif
    let start_pos = match_start + 1
  endwhile
endfunction

function! ShiftOrgDateDays(days)

  let line = getline('.')
  let cursor_col = col('.')
  
  " Match dates in format <YYYY-MM-DD Day> with optional postfixes (time, recurring pattern)
  
  " Find all date patterns in the current line
  let [year, month, day, day_name, postfix, match_start, date_end] = ExtractDateFromCurrentLine()

  " Calculate timestamp
  let timestamp = 0
  
  " Need to convert the year, month, day to timestamp
  " Since Vim's strftime is limited, use a different approach
  
  " First get current timestamp
  let current_timestamp = localtime()
  " Get current year, month, day
  let current_ymd = strftime('%Y-%m-%d', current_timestamp)
  let [c_year, c_month, c_day] = split(current_ymd, '-')
  
  " Calculate days difference between target date and current date
  let days_diff = 0
  let days_diff += (year - c_year) * 365
  let days_diff += (month - c_month) * 30
  let days_diff += (day - c_day)
  
  " Calculate new timestamp by adding/subtracting days
  let new_timestamp = current_timestamp + (days_diff + a:days) * 86400
  
  let new_date = strftime('%Y-%m-%d', new_timestamp)

  let new_day = strftime('%a', new_timestamp)
  
  " Create new date tag - preserving the original postfix
  let new_date_tag = '<' . new_date . ' ' . new_day . postfix . '>'
  
  call UpdateDateOnCurrentLine(line, match_start, new_date_tag, date_end)
  
  " Keep cursor at the same relative position
  call cursor(line('.'), cursor_col)
endfunction

autocmd FileType org nnoremap <buffer> <S-Right> :call ShiftOrgDateDays(1)<CR>
autocmd FileType org nnoremap <buffer> <S-Left> :call ShiftOrgDateDays(-1)<CR>

autocmd FileType org nnoremap <buffer> <Space>mds :call AddOrgDateWithType('SCHEDULED')<CR>
autocmd FileType org nnoremap <buffer> <Space>mdd :call AddOrgDateWithType('DEADLINE')<CR>

" Creates a dynamic buffer for viewing and navigating org files



" Define the orgcal filetype and syntax
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
  
  " Set highlighting colors
  autocmd FileType orgcal highlight OrgCalTitle ctermfg=Yellow guifg=#ffff00 gui=bold
  autocmd FileType orgcal highlight OrgCalTodo guifg=DarkOrange gui=bold
  autocmd FileType orgcal highlight OrgCalDone ctermfg=Green guifg=#66ff66
  autocmd FileType orgcal highlight OrgCalScheduled ctermfg=Cyan guifg=#6666ff gui=bold
  autocmd FileType orgcal highlight OrgCalDeadline  gui=bold
  autocmd FileType orgcal highlight OrgCalDate ctermfg=Blue guifg=#6699ff
  autocmd FileType orgcal highlight link OrgCalHiddenMeta Conceal
  
  " Enable concealing of metadata
  autocmd FileType orgcal setlocal conceallevel=2
  autocmd FileType orgcal setlocal concealcursor=nvic
augroup END

" Function to store metadata in a hidden marker
function! s:OrgCalHiddenMeta(data)
  return "‡" . a:data . "‡"
endfunction

" Function to parse org files and populate the calendar buffer
function! s:PopulateOrgCalendar(mode, current_timestamp)
  " Clear any existing content
  silent! normal! ggdG
  
  
  let line_num = 4

  if exists('g:orgcal_filepaths') == 0 
    Error "Cannot populate org calendar: exp variable g:orgcal_filepaths to exist'
    return
  endif
  if empty(g:orgcal_filepaths)
    Error "Cannot populate org calendar: exp variable g:orgcal_filepaths to not be empty'
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

  " Add header
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
    
    " Find all headers for this date
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
    
    " Create a timestamp for the specific date
    " This approximation works for our purpose
    let days_diff = 0
    let current_ymd = strftime('%Y-%m-%d', timestamp)
    let [c_year, c_month, c_day] = split(current_ymd, '-')
    let days_diff += (year - c_year) * 365
    let days_diff += (month - c_month) * 30
    let days_diff += (day - c_day)
    let date_timestamp = timestamp + (days_diff * 86400)
    
    " Get day name
    let day_name = strftime('%A', date_timestamp)
    let current_date = strftime('%Y-%m-%d')
    let this_iteration_is_for_current_date = current_date == ordered_prefix
    
    " Add the date header
    if this_iteration_is_for_current_date
      let line_to_put_cursor_after_rendering = line_num
    endif
    call append(line_num, day_name . " " . ordered_prefix)
    let line_num += 1

    if len(items_on_this_date) < 1
      continue
    endif
    
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

    " add each line at corresponding day
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
          call add(upcoming_day_lines_map[upcoming_days_deadline], formatted_line)
        endif
      endfor
    endif

    for i in range(upcoming_deadline_days_in_future)
      let lines = upcoming_day_lines_map[i+1]
      for line in lines
        call append(line_num, line)
        let line_num += 1
      endfor
    endfor
    
    " Add a blank line after each date
    call append(line_num, "")
    let line_num += 1
  endfor
  
  " Position cursor at the beginning
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
  " Check if the global variable exists with g: prefix
  let full_var_name = 'g:' . a:global_variable_name
  
  if exists(full_var_name)
    " Return the value of the global variable
    return eval(full_var_name)
  else
    " Return the default value if the variable doesn't exist
    return a:default
  endif
endfunction

function! ExtractHeadersWithDatesFromLines(lines, date_str_prefixes_to_load_into_calendar, upcoming_days_in_future_deadline_date_str_prefixes_to_load_into_calendar, org_file, org_file_name)
  " Add file header
  let line_num = 0
  
  " Read file content
  let in_todo_item = 0
  let todo_line_num = 0

  let response = []
  
  let lines_to_iterate = len(a:lines) - 1 " no need to go through the last line since no dates can be below that
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

    let headerDate = {
      \ "headerText": headline,
      \ "dates": dates_with_types_within_range,
      \ "hiddenMetaLink": s:OrgCalHiddenMeta(a:org_file . "|" . header_line_col),
      \ "orgFileName": a:org_file_name,
      \ "upcomingDeadlineDays": upcoming_deadline_days_in_future
      \ }
    call add(response, headerDate)
  endfor
  return response
endfunction

function! GetDatePrefixesByRangeFromToday(amount_days_in_past_from_current_date, amount_days_in_future_from_current_date, current_timestamp)
    
    " Create a list of dates within the span
    let dates = []
    
    " Add dates from span_days before today to span_days after today
    for day_offset in range(-a:amount_days_in_past_from_current_date, a:amount_days_in_future_from_current_date)
      let date_timestamp = IncrementTimestampByDays(a:current_timestamp, day_offset)
      let date_str = ConvertTimestampToDatePrefixStr(date_timestamp)
      call add(dates, date_str)
    endfor
    
    " Set the result to the dates array (already sorted chronologically)
    return dates
endfunction

function! ConvertTimestampToDatePrefixStr(timestamp)
  return strftime('%Y-%m-%d', a:timestamp)
endfunction

function! IncrementTimestampByDays(timestamp, days)
  return a:timestamp + (a:days * 86400)  " 86400 seconds in a day
endfunction

function! GetOrderedDatePrefixesToLoadIntoCalendar(mode, relative_current_timestamp)
  " Handle 'daily' mode
  if a:mode ==# 'daily'
    " Default span if global variable isn't set
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
  
  " Look for date patterns with their types
  let date_types = ['DEADLINE', 'SCHEDULED']
  let date_pattern = '<\(\d\{4}-\d\{2\}-\d\{2\}\)\s\+\w\{3\}\(\s\+\(\d\{1,2}:\d\{2\}\(-\d\{1,2}:\d\{2\}\)\?\)\)\?'
  
  for date_type in date_types
    " Start searching from beginning of line
    let start_pos = 0
    
    while 1
      " Find the date type in the line
      let type_pos = match(line, date_type . ':', start_pos)
      if type_pos == -1
        break
      endif
      
      " Find the date after the type
      let date_pos = match(line, date_pattern, type_pos)
      
      " If we found a date after the type and it's close enough (within 20 chars)
      if date_pos != -1 && date_pos - type_pos < 20
        " Extract the date value
        let date_match = matchlist(line, date_pattern, date_pos)
        if len(date_match) > 1
          " Create result dictionary with date and type
          let result = {"dateStr": date_match[1], "typeStr": date_type}
          
          " Add time if it exists
          if len(date_match) > 3 && date_match[3] != ''
            let result["timeStr"] = date_match[3]
          endif
          
          " Add to results
          call add(results, result)
        endif
      endif
      
      " Move past this occurrence
      let start_pos = type_pos + len(date_type)
    endwhile
  endfor
  
  return results
endfunction

function! GetOrgHeaderTextFromLine(line)
  return substitute(a:line,  '^\*\+\s', '', '')
endfunction

" Function to open the org file at the specified location
function! s:OrgCalOpenEntry()
  let line = getline('.')
  
  " Extract file path and line number from hidden markers
  let meta_pattern = '‡\(.\{-}\)‡'
  let matches = matchlist(line, meta_pattern)
  
  if len(matches) > 1
    " Change from colon to pipe separator
    let file_info = split(matches[1], '|')
    if len(file_info) >= 2
      let file_path = file_info[0]
      let line_number = file_info[1]
      
      " Open the file at the specified line
      execute 'edit +' . line_number . ' ' . file_path
    endif
  endif
endfunction

" Function to open the org file in a vertical split or focus an existing window
function! s:OrgCalOpenEntryVSplit()
  let line = getline('.')
  
  " Extract file path and line number from hidden markers
  let meta_pattern = '‡\(.\{-}\)‡'
  let matches = matchlist(line, meta_pattern)
  
  if len(matches) > 1
    " Split the metadata to get file path and line number
    let file_info = split(matches[1], '|')
    if len(file_info) >= 2
      let file_path = file_info[0]
      let line_number = file_info[1]
      
      " Check if the file is already open in a window
      let buf_nr = bufnr(file_path)
      if buf_nr > 0
        " File is loaded in a buffer, check if it's visible
        let win_id = bufwinid(buf_nr)
        if win_id != -1
          " Buffer is visible in a window, just focus it
          call win_gotoid(win_id)
          " Move to the specified line
          execute line_number
          normal! z.
          return
        endif
      endif
      
      " File isn't visible in any window, open in a vertical split
      execute 'vsplit +' . line_number . ' ' . file_path
      normal! z.
    endif
  endif
endfunction

" Function to refresh the calendar view
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

" Function to create and populate the org calendar buffer
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
    " Create a new buffer in the current window instead of a split
    enew
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nowrap
    setlocal nonumber
    setlocal nofoldenable
    let g:orgcal_relative_now = localtime()
    
    " Set buffer name and options
    execute 'file orgcal'
    setlocal filetype=orgcal
  endif
  
  setlocal modifiable
  
  " Populate the buffer
  call s:PopulateOrgCalendar(a:mode, g:orgcal_relative_now)
  
  " Set up custom key mappings for this buffer
  nnoremap <buffer> <CR> :call <SID>OrgCalOpenEntry()<CR>
  nnoremap <buffer> <Tab> :call <SID>OrgCalOpenEntryVSplit()<CR>
  nnoremap <buffer> q :call <SID>QuitOrgCalendar()<CR>
  nnoremap <buffer> r :call <SID>ReloadOrgCalendar()<CR>
  nnoremap <buffer> m :call <SID>RefreshOrgCalendar('monthly', localtime())<CR>
  nnoremap <buffer> d :call <SID>RefreshOrgCalendar('daily', localtime())<CR>
  nnoremap <buffer> [ :call <SID>MoveCalendarTimeWindowStepsAndRefresh(1)<CR>
  nnoremap <buffer> ] :call <SID>MoveCalendarTimeWindowStepsAndRefresh(-1)<CR>
  
  " Make buffer non-modifiable
  setlocal nomodifiable
endfunction

" Command and mapping to open the org calendar
command! -nargs=0 OrgCal call s:OpenOrgCalendar('daily')
nnoremap <C-c> :OrgCal<CR>
