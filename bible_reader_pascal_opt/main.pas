program BibleReaderOpt;

{$mode fpc}
{$PACKRECORDS C}
{$MACRO ON}
{$COPERATORS ON}

(*
  Minimizing dependencies:
  - No 'uses ctypes' (define types manually)
  - No ParamStr (use ArgC/ArgV)
  - No Strings (use PChar)
*)

const
  libc = 'c';

type
  cint = longint;
  csize_t = longword; // 32-bit? On 64-bit it is qword.
  // csize_t in FPC on 64-bit: QWord.
  // Let's use PtrUInt for csize_t which matches pointer size.
  csize_alias = PtrUInt;
  
  PChar = ^Char;
  PPChar = ^PChar;
  PFile = Pointer;

// LibC bindings
function popen(command: PChar; mode: PChar): PFile; cdecl; external libc name 'popen';
function pclose(stream: PFile): cint; cdecl; external libc name 'pclose';
function fgets(s: PChar; size: cint; stream: PFile): PChar; cdecl; external libc name 'fgets';
function printf(format: PChar): cint; varargs; cdecl; external libc name 'printf';
function putchar(c: cint): cint; cdecl; external libc name 'putchar';
function fgetc(stream: PFile): cint; cdecl; external libc name 'fgetc';
function ungetc(c: cint; stream: PFile): cint; cdecl; external libc name 'ungetc';
function strlen(s: PChar): csize_alias; cdecl; external libc name 'strlen';
function strcasecmp(s1, s2: PChar): cint; cdecl; external libc name 'strcasecmp';
function atoi(s: PChar): cint; cdecl; external libc name 'atoi';
function strchr(s: PChar; c: cint): PChar; cdecl; external libc name 'strchr';
function strstr(haystack, needle: PChar): PChar; cdecl; external libc name 'strstr';
function strncmp(s1, s2: PChar; n: csize_alias): cint; cdecl; external libc name 'strncmp';

// Access ArgC/ArgV from System unit
// They are initialized by default RTL entry
// Argv is PPChar

const
  MAX_LINE = 4096;
  COLOR_RED = #27'[31m'#0;
  COLOR_RESET = #27'[0m'#0;
  CMD_XZ = 'xz -d -c ../bible_data.txt.xz'#0;
  MODE_R = 'r'#0;
  FMT_PREFIX_H = #10'### '#0;
  FMT_SUFFIX_H = ' ###'#10#0;
  FMT_STR = '%s'#0;
  FMT_META = '[%d:%d] '#0;
  FMT_REFS = ' ('#0;
  FMT_REFS_END = ')'#0;

var
  normalizeBuf: array[0..MAX_LINE*2] of Char;

function Normalize(str: PChar): PChar;
var
  outPtr: PChar;
  c1, c2: byte;
begin
  outPtr := @normalizeBuf[0];
  while (byte(str^) <> 0) do
  begin
    c1 := byte(str[0]);
    if (c1 > 127) and (byte(str[1]) <> 0) then
    begin
       c2 := byte(str[1]);
       // Using hex constants for UTF8
       // Ă = C4 82 -> a
       // â = C3 A2 -> a
       // î = C3 AE -> i
       // ș = C8 99 -> s
       // Ș = C8 98 -> S (handled?)
       // ț = C8 9B -> t
       // ţ = C5 A3 -> t
       // ş = C5 9F -> s
       // Hardcoded normalization
       if (c1 = $C4) and (c2 = $83) then begin outPtr^ := 'a'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C3) and (c2 = $A2) then begin outPtr^ := 'a'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C3) and (c2 = $AE) then begin outPtr^ := 'i'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C8) and (c2 = $99) then begin outPtr^ := 's'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C5) and (c2 = $9F) then begin outPtr^ := 's'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C8) and (c2 = $9B) then begin outPtr^ := 't'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C5) and (c2 = $A3) then begin outPtr^ := 't'; Inc(outPtr); Inc(str, 2); Continue; end;
       if (c1 = $C4) and (c2 = $82) then begin outPtr^ := 'a'; Inc(outPtr); Inc(str, 2); Continue; end; // Capital Ă? C4 82 is 'Ă'
    end;
    
    // Lowercase ASCII
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
  while byte(p^) <> 0 do
  begin
    if strncmp(p, '<span class=''Isus''>', 19) = 0 then
    begin
      printf(COLOR_RED);
      Inc(p, 19);
    end
    else if strncmp(p, '<span class="Isus">', 19) = 0 then // Quote variant
    begin
      printf(COLOR_RED);
      Inc(p, 19);
    end
    else if strncmp(p, '</span>', 7) = 0 then
    begin
      printf(COLOR_RESET);
      Inc(p, 7);
    end
    else
    begin
      putchar(cint(byte(p^))); // Cast to cint
      Inc(p);
    end;
  end;
end;

function GetArg(idx: cint): PChar;
begin
  if idx >= ArgC then Exit(nil);
  GetArg := ArgV[idx];
end;

var
  fp: PFile;
  line: array[0..MAX_LINE] of Char;
  currentBook: array[0..100] of Char;
  titleBuf: array[0..MAX_LINE] of Char;
  refsBuf: array[0..MAX_LINE] of Char;
  queryNorm: array[0..MAX_LINE] of Char;
  
  argBook: PChar;
  argChapStr: PChar;
  argVerseStr: PChar;
  
  targetChapter: cint;
  targetVerseNum: cint;
  
  chap: cint;
  vNum: cint;
  
  tLen, lineLen: csize_alias;
  p: PChar;
  textStart: PChar;
  
  c: cint;
  i: cint;
  
begin
  if ArgC < 3 then
  begin
      printf('Usage: bible_reader_pascal_opt read Book <Chap> <Verse>'#10#0);
      Halt(0);
  end;
  
  argBook := GetArg(2);
  targetChapter := 0;
  argChapStr := GetArg(3);
  if argChapStr <> nil then targetChapter := atoi(argChapStr);
  
  targetVerseNum := 0;
  argVerseStr := GetArg(4);
  if argVerseStr <> nil then targetVerseNum := atoi(argVerseStr);
  
  fp := popen(CMD_XZ, MODE_R);
  if fp = nil then Halt(1);
  
  currentBook[0] := #0;
  titleBuf[0] := #0;
  chap := 0;
  
  while fgets(line, MAX_LINE, fp) <> nil do
  begin
     lineLen := strlen(line);
     // Trim newline
     if (lineLen > 0) and (line[lineLen-1] = #10) then line[lineLen-1] := #0;
     
     if line[0] = '#' then
     begin
         p := @line[2];
         i := 0; while byte(p^) <> 0 do begin currentBook[i] := p^; Inc(p); Inc(i); end; currentBook[i] := #0;
         chap := 0;
         titleBuf[0] := #0;
     end
     else if line[0] = '=' then
     begin
         chap := atoi(@line[2]);
         titleBuf[0] := #0;
     end
     else if line[0] = 'T' then
     begin
         p := @line[2];
         i := 0; while byte(p^) <> 0 do begin titleBuf[i] := p^; Inc(p); Inc(i); end; titleBuf[i] := #0;
     end
     else if (line[0] >= '0') and (line[0] <= '9') then
     begin
         vNum := atoi(line);
         
         if (strcasecmp(argBook, currentBook) = 0) then
         begin
             if (chap = targetChapter) or (targetChapter = 0) then
             begin
                 if (targetVerseNum = 0) or (targetVerseNum = vNum) then
                 begin
                     // Check Refs
                     c := fgetc(fp);
                     refsBuf[0] := #0; // Empty by default
                     
                     if c = Ord('R') then
                     begin
                         fgets(refsBuf, MAX_LINE, fp);
                         tLen := strlen(refsBuf);
                         if (tLen > 0) and (refsBuf[tLen-1] = #10) then refsBuf[tLen-1] := #0;
                     end
                     else if c <> -1 then
                     begin
                         ungetc(c, fp);
                     end;
                     
                     // Print
                     if titleBuf[0] <> #0 then
                     begin
                         printf(FMT_PREFIX_H); printf(FMT_STR, @titleBuf); printf(FMT_SUFFIX_H);
                         titleBuf[0] := #0;
                     end;
                     
                     printf(FMT_META, chap, vNum);
                     
                     textStart := strchr(line, 32);
                     if textStart <> nil then
                     begin
                         PrintFormatted(textStart + 1);
                     end;
                     
                     if refsBuf[0] <> #0 then // Not empty
                     begin
                        printf(FMT_REFS);
                        // Skip first char (space?) Refs are 'R ...' -> buffer starts with space?
                        // fgets reads " <refs...>"
                        // Usually input is "R <refs>". fgets reads "<refs>".
                        // Wait, my logic: read R char. call fgets.
                        // "R Gen 1:1" -> c='R'. fgets reads " Gen 1:1".
                        // Yes, starts with space.
                        // Skip space.
                        if refsBuf[0] = ' ' then printf(FMT_STR, @refsBuf[1])
                        else printf(FMT_STR, @refsBuf[0]);
                        printf(FMT_REFS_END);
                     end;
                     printf(#10#0);
                 end;
             end;
         end;
         titleBuf[0] := #0;
     end;
  end;
  pclose(fp);
end.
