program idxparse;
// 
// Author: Mick Grove
// Date: October 2011
//
{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  Windows,
  PerlRegex,
  uRegUtils in 'uRegUtils.pas';

procedure FileSearch(const PathName, FileName: string; const InDir: boolean; var slFiles:
  TStringList);
var
  Rec                         : TSearchRec;
  Path                        : string;
begin
  Path := IncludeTrailingPathDelimiter(PathName);

  if SysUtils.FindFirst(Path + FileName, faAnyFile - faDirectory, Rec) = 0 then
  begin
    try
      repeat
        slFiles.Add(Path + Rec.Name);
      until SysUtils.FindNext(Rec) <> 0;
    finally
      SysUtils.FindClose(Rec);
    end;
  end;

  if not InDir then
    Exit;

  if SysUtils.FindFirst(Path + '*.*', faDirectory, Rec) = 0 then
    try
      repeat
        if ((Rec.Attr and faDirectory) <> 0) and (Rec.Name <> '.') and (Rec.Name <>
          '..') then
          FileSearch(Path + Rec.Name, FileName, True, slFiles);
      until FindNext(Rec) <> 0;
    finally
      SysUtils.FindClose(Rec);
    end;
end; //procedure FileSearch

function MemoryStreamToString(var M: TMemoryStream): string;
var
  SS                          : TStringStream;
begin
  if M <> nil then
  begin
    SS := TStringStream.Create('');
    try
      M.Position := 0;
      SS.CopyFrom(M, M.Size);
      Result := SS.DataString;
    finally
      SS.Free;
    end;
  end
  else
  begin
    Result := '';
  end;
end;

{:Retrieves file size.
  @returns -1 for unexisting/unaccessible file or file size.
}

function MgFileSize(const fileName: string): int64;
var
  fHandle                     : DWORD;
begin
  fHandle := CreateFile(PChar(fileName), 0, 0, nil, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, 0);

  if fHandle = INVALID_HANDLE_VALUE then
    Result := -1
  else
    try
      Int64Rec(Result).Lo := GetFileSize(fHandle, @Int64Rec(Result).Hi);
    finally
      CloseHandle(fHandle);
    end;
end; { MgFileSize }

procedure BeginWork(sPath: string);
var
  slFilesFound                : TStringList;
  bRecursive                  : Boolean;
  sCur                        : string;
  msCurFile                   : TMemoryStream;
  S                           : UTF8String;
  Regex                       : TPerlRegEx;
  sTimestamp                  : string;
  sCurUrl                     : string;
  iFileSizeBytes              : Int64;
const
  MAX_BYTES_IDX               = 102400; // = 100k
begin
  bRecursive := True;
  slFilesFound := TStringList.Create;
  Regex := TPerlRegex.Create;
  try
    FileSearch(sPath, '*.idx', bRecursive, slFilesFound);

    for sCur in slFilesFound do
    begin
      if FileExists(sCur) then
      begin
        iFileSizeBytes := MgFileSize(sCur);
        if (iFileSizeBytes < 0) or (iFileSizeBytes > MAX_BYTES_IDX) then
          Continue;

        msCurFile := TMemoryStream.Create;
        try
          msCurFile.LoadFromFile(sCur);
          msCurFile.Position := 0;

          S := MemoryStreamToString(msCurFile);

          Regex.RegEx :=
            '[0-3][0-9] [a-zA-Z][a-z][a-z] [0-9][0-9][0-9][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9]';
          Regex.Options := [preMultiLine];
          Regex.Subject := S;

          if Regex.Match then
          begin
            repeat
              sTimestamp := Regex.MatchedText;
            until not Regex.MatchAgain;
          end;

          Regex.RegEx :=
            '(?:(?:https?|ftp|file)://|www\.|ftp\.)'#10 +
            #9'  (?:\([-A-Z0-9+&@#/%=~_|$?!:,.]*\)|[-A-Z0-9+&@#/%=~_|$?!:,.])*'#10 +
            #9'  (?:\([-A-Z0-9+&@#/%=~_|$?!:,.]*\)|[A-Z0-9+&@#/%=~_|$])';
          Regex.Options := [preCaseless, preMultiLine, preExtended];
          Regex.Subject := S;

          if Regex.Match then
          begin
            repeat
              sCurUrl := Regex.MatchedText;
              Regex.RegEx := 'https?://.*\.verisign.com.*$|https?://.*\.thawte.com.*$';
              Regex.Options := [preCaseless, preMultiLine, preExtended];
              Regex.Subject := sCurUrl;
              if not Regex.Match then
              begin
                Writeln(sTimestamp + '|' + sCurUrl + '|' + sCur);
              end;
            until not Regex.MatchAgain;
          end;

        finally
          FreeAndNil(msCurFile);
        end;
      end;
    end;
  finally
    FreeAndNil(slFilesFound);
  end;
end;

procedure ShowUsage();
begin
  WriteLn('');
  WriteLn(ExtractFileName(ParamStr(0)) +
    ' v1.0 -- parse java applet cache IDX files'#13#10);
  WriteLn('  *** note: skips files larger than 100k!'#13#10);
  WriteLn('Usage: ' + ExtractFileName(ParamStr(0)) + ' -p|-a');    
  WriteLn(#9'-p path to java cache');
  WriteLn(#9'-a display results for all users on system using default cache location');
  WriteLn('');
  WriteLn('Examples:');
  Writeln('=========='#13#10);
  WriteLn(#9'idxparse.exe -p "C:\Documents and Settings\<user>\Local Settings\Application Data\Sun\Java\Deployment\cache"');
  WriteLn('');
  WriteLn(#9'idxparse.exe -p "C:\Users\<user>\AppData\LocalLow\Sun\Java\Deployment\cache"');
  WriteLn('');
  WriteLn(#9'idxparse.exe -a'#13#10);

end;

var
  idx                         : integer;
  sCurParamStr                : string;
  sPath                       : string;
  bCheckAllUsers              : boolean;
  slProfiles                  : TStringList;
  sCurProfile                 : string;
begin
  try
    if System.ParamCount < 1 then
    begin
      ShowUsage;
      Exit;
    end;

    bCheckAllUsers := False; //defualt
    sPath := ''; //default

    for idx := 1 to System.ParamCount do
    begin
      sCurParamStr := ParamStr(idx);
      if SameText(sCurParamStr, '/?') or
        SameText(ParamStr(idx), '-?') then
      begin
        ShowUsage;
        Exit;
      end;

      if SameText(sCurParamStr, '/h') or
        SameText(ParamStr(idx), '-h') then
      begin
        ShowUsage;
        Exit;
      end;

      if SameText(sCurParamStr, '/p') or
        SameText(ParamStr(idx), '-p') then
      begin
        sPath := ParamStr(idx + 1);
        Continue;
      end;

      if SameText(sCurParamStr, '/a') or
        SameText(ParamStr(idx), '-a') then
      begin
        bCheckAllUsers := True;
        Continue;
      end;
    end;

    if not bCheckAllUsers then
    begin
      if not DirectoryExists(sPath) then
      begin
        ShowUsage;
        WriteLn('*** error: path does not exist: ' + '<' + sPath + '>');
        Writeln('Enter a valid path.');
        Exit;
      end;
    end;

    if bCheckAllUsers then
    begin
      slProfiles := TStringList.Create;
      try
        sPath := sPath + SysUtils.GetEnvironmentVariable('SystemDrive');
        uRegUtils.GetProfileList(slProfiles);

        for sCurProfile in slProfiles do
        begin
          OutputDebugString(PChar(sCurProfile));
          if DirectoryExists(sCurProfile + '\AppData') then
          begin
            sPath := sCurProfile + '\AppData';
          end
          else
          begin
            sPath := sCurProfile + '\Local Settings\Application Data';
            //sPath := sCurProfile; //+ '\Local Settings\Application Data';
          end;

          if DirectoryExists(sPath) then
          begin
            BeginWork(sPath);
          end;
        end;
      finally
        FreeAndNil(slProfiles);
      end;
    end
    else
    begin
      BeginWork(sPath);
    end;
  except
    on E: Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;
end.

