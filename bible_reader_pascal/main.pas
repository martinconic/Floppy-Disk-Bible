program BibleReader;

{$mode objfpc}{$H+}
{$linklib c}

uses
  ctypes;

const
  libc = 'c';

type
  PFile = Pointer;

// LibC Imports
function popen(command: PChar; mode: PChar): PFile; cdecl; external libc name 'popen';
function pclose(stream: PFile): cint; cdecl; external libc name 'pclose';
function fgets(s: PChar; size: cint; stream: PFile): PChar; cdecl; external libc name 'fgets';
function printf(format: PChar): cint; varargs; cdecl; external libc name 'printf'; // Varargs support? FPC supports `varargs`
function putchar(c: cint): cint; cdecl; external libc name 'putchar';
function fgetc(stream: PFile): cint; cdecl; external libc name 'fgetc';
function ungetc(c: cint; stream: PFile): cint; cdecl; external libc name 'ungetc';
function strlen(s: PChar): csize_t; cdecl; external libc name 'strlen';
function strcmp(s1, s2: PChar): cint; cdecl; external libc name 'strcmp';
function strcasecmp(s1, s2: PChar): cint; cdecl; external libc name 'strcasecmp';
function atoi(s: PChar): cint; cdecl; external libc name 'atoi';
function strchr(s: PChar; c: cint): PChar; cdecl; external libc name 'strchr';
function strcspn(s1, s2: PChar): csize_t; cdecl; external libc name 'strcspn';
function strncmp(s1, s2: PChar; n: csize_t): cint; cdecl; external libc name 'strncmp';
function strstr(haystack, needle: PChar): PChar; cdecl; external libc name 'strstr';

const
  MAX_LINE = 4096;
  COLOR_RED = #27'[31m'#0;
  COLOR_RESET = #27'[0m'#0;
  CMD_XZ = 'xz -d -c ../bible_data.txt.xz'#0;
  MODE_R = 'r'#0;
  FMT_STR = '%s'#0;
  
var
  normalizeBuf: array[0..MAX_LINE*2] of Char;

function Normalize(str: PChar): PChar;
var
  outPtr: PChar;
  c1, c2: byte;
begin
  outPtr := @normalizeBuf[0];
  while (str^ <> #0) do
  begin
    c1 := byte(str[0]);
    if (c1 > 127) and (str[1] <> #0) then
    begin
       c2 := byte(str[1]);
       if (c1 = $C4) and (c2 = $83) then begin outPtr^ := 'a'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C3) and (c2 = $A2) then begin outPtr^ := 'a'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C3) and (c2 = $AE) then begin outPtr^ := 'i'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C8) and (c2 = $99) then begin outPtr^ := 's'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C5) and (c2 = $9F) then begin outPtr^ := 's'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C8) and (c2 = $9B) then begin outPtr^ := 't'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C5) and (c2 = $A3) then begin outPtr^ := 't'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C4) and (c2 = $82) then begin outPtr^ := 'a'; Inc(outPtr); Inc(str, 2); Continue; end;
    end;
    
    if (c1 >= Ord('A')) and (c1 <= Ord('Z')) then
      outPtr^ := Char(c1 + 32)
    else
      outPtr^ := Char(c1);
      
    Inc(outPtr);
    Inc(str);
  end;
  outPtr^ := #0;
  Normalize := @normalizeBuf[0];
end;

procedure PrintFormatted(text: PChar);
var
  p: PChar;
begin
  p := text;
  while p^ <> #0 do
  begin
    if StrNCmp(p, '<span class=\''Isus\''>', 21) = 0 then
    begin
      printf(COLOR_RED);
      Inc(p, 21);
    end
    else if StrNCmp(p, '<span class=''Isus''>', 19) = 0 then
    begin
      printf(COLOR_RED);
      Inc(p, 19);
    end
    else if StrNCmp(p, '</span>', 7) = 0 then
    begin
      printf(COLOR_RESET);
      Inc(p, 7);
    end
    else
    begin
      putchar(cint(p^));
      Inc(p);
    end;
  end;
end;

var
  fp: PFile;
  line: array[0..MAX_LINE] of Char;
  currentBook: array[0..100] of Char;
  currentChapter: cint;
  currentTitle: array[0..MAX_LINE] of Char;
  lastRefs: array[0..MAX_LINE] of Char;
  queryNorm: array[0..MAX_LINE] of Char;
  
  cmd: PChar;
  arg1: PChar;
  
  targetChapter: cint;
  targetVerseNum: cint;
  searchCount: cint;
  
  len: csize_t;
  verseEnd: PChar;
  vNum: cint;
  text: PChar;
  
  match: Boolean;
  c: cint;
  rp: PChar;
  i: cint;
  
begin
  if ParamCount < 1 then Halt(1);
  
  cmd := PChar(ParamStr(1));
  arg1 := #0; if ParamCount >= 2 then arg1 := PChar(ParamStr(2));
  
  fp := popen(CMD_XZ, MODE_R);
  if fp = nil then Halt(1); // minimal error handle
  
  currentBook[0] := #0;
  currentChapter := 0;
  currentTitle[0] := #0;
  
  queryNorm[0] := #0;
  if StrCmp(cmd, 'search') = 0 then
  begin
      if arg1 <> nil then 
      begin
         rp := Normalize(arg1);
         i := 0; while rp^ <> #0 do begin queryNorm[i] := rp^; Inc(rp); Inc(i); end; queryNorm[i] := #0;
      end;
  end;

  targetChapter := 0;
  if ParamCount >= 3 then targetChapter := atoi(PChar(ParamStr(3)));
  targetVerseNum := 0;
  if ParamCount >= 4 then targetVerseNum := atoi(PChar(ParamStr(4)));
  
  searchCount := 0;

  while fgets(line, MAX_LINE, fp) <> nil do
  begin
    len := strlen(line);
    if (len > 0) and (line[len-1] = #10) then line[len-1] := #0;
    
    if line[0] = '#' then
    begin
       rp := @line[2]; i:=0; while rp^ <> #0 do begin currentBook[i] := rp^; Inc(rp); Inc(i); end; currentBook[i] := #0;
       currentChapter := 0;
       currentTitle[0] := #0;
       Continue;
    end;

    if line[0] = '=' then
    begin
       currentChapter := atoi(@line[2]);
       currentTitle[0] := #0;
       Continue;
    end;
    
    if line[0] = 'T' then
    begin
       rp := @line[2]; i:=0; while rp^ <> #0 do begin currentTitle[i] := rp^; Inc(rp); Inc(i); end; currentTitle[i] := #0;
       Continue;
    end;
    
    if (line[0] >= '0') and (line[0] <= '9') then
    begin
       verseEnd := strchr(line, 32);
       if verseEnd = nil then Continue;
       
       verseEnd^ := #0;
       vNum := atoi(line);
       text := verseEnd + 1;
       
       match := False;
       
       if StrCmp(cmd, 'read') = 0 then
       begin
           if (strcasecmp(currentBook, arg1) = 0) and (currentChapter = targetChapter) then
           begin
               if (targetVerseNum = 0) or (targetVerseNum = vNum) then match := True;
           end;
       end
       else if StrCmp(cmd, 'search') = 0 then
       begin
           if strstr(Normalize(text), queryNorm) <> nil then match := True;
       end;
       
       if match then
       begin
           c := fgetc(fp);
           lastRefs[0] := #0;
           if c = Ord('R') then
           begin
                fgets(lastRefs, MAX_LINE, fp);
                len := strlen(lastRefs);
                if (len > 0) and (lastRefs[len-1] = #10) then lastRefs[len-1] := #0;
           end
           else if c <> -1 then { -1 is EOF usually, check cint? }
           begin
                ungetc(c, fp);
           end;
           
           if currentTitle[0] <> #0 then
           begin
               // printf("\n### %s ###\n", currentTitle);
               printf(#10'### '); printf(FMT_STR, currentTitle); printf(' ###'#10);
               currentTitle[0] := #0;
           end;
           
           // printf("[%d:%d] ", currentChapter, vNum);
           printf('['); 
           // Need int print helper? Varargs might work with FPC
           // FPC support for varargs in cdecl? Yes.
           // But type safety?
           // Actually let's just write a helper for ints to be safe/small if varargs fails?
           // No, varargs works.
           // Format string needs to be PChar
           printf('%d:%d] ', currentChapter, vNum);
           
           PrintFormatted(text);
           
           if lastRefs[0] <> #0 then
           begin
               printf(' (');
               // Skip space? " Refs..."
               // lastRefs is " Refs...". 
               rp := @lastRefs[1]; // Skip space
               while rp^ <> #0 do
               begin
                   if rp^ = ';' then printf(', ')
                   else putchar(cint(rp^));
                   Inc(rp);
               end;
               printf(')');
           end;
           printf(#10);
           
           if StrCmp(cmd, 'search') = 0 then
           begin
               Inc(searchCount);
               if searchCount > 50 then Break;
           end;
       end;
       currentTitle[0] := #0;
    end;
  end;
  
  pclose(fp);
end.
