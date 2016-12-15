unit uRegUtils;

interface

uses

  Classes,
  PerlRegEx,
  Windows,
  StrUtils,
  SysUtils,
  Registry;

procedure GetProfileList(var slProfileList: TStringList);

implementation

function GetRegistryData(RootKey: HKEY; Key, Value: string): string;
var
  Reg                         : TRegistry;
  RegDataType                 : TRegDataType;
  DataSize, Len               : integer;
  s                           : string;
  sReturnValue                : string;
begin
  sReturnValue := '';

  Reg := TRegistry.Create; //(KEY_READ);
  try
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;

      //if Reg.RegistryConnect(sMachine) then
      begin
        if Reg.KeyExists(Key) then
        begin
          if Reg.OpenKeyReadOnly(Key) then
          begin
            try
              RegDataType := Reg.GetDataType(Value);
              if (RegDataType = rdString) or (RegDataType = rdExpandString) then
              begin
                sReturnValue := Reg.ReadString(Value)
              end
              else if RegDataType = rdInteger then
              begin
                sReturnValue := IntToStr(Reg.ReadInteger(Value));
              end
              else if RegDataType = rdBinary then
              begin
                DataSize := Reg.GetDataSize(Value);
                if DataSize = -1 then
                begin
                  sReturnValue := '';
                  //raise Exception.Create(SysErrorMessage(ERROR_CANTREAD));
                  //DONE: remove these when completed
                end;
                SetLength(s, DataSize);
                Len := Reg.ReadBinaryData(Value, PChar(s)^, DataSize);
                if Len <> DataSize then
                begin
                  sReturnValue := '';
                  //raise Exception.Create(SysErrorMessage(ERROR_CANTREAD));
                  //DONE: remove these when completed
                end;
                sReturnValue := s;
              end
              else if RegDataType = rdUnknown then
              begin
                sReturnValue := '';
              end;
            except
              s := ''; // Deallocates memory if allocated
              Reg.CloseKey;
            end;
            Reg.CloseKey;
          end
          else
          begin
            sReturnValue := '';
          end;

        end;
      end;
    except
      FreeAndNil(Reg);
    end;
  finally
    FreeAndNil(Reg);
  end;
  Result := sReturnValue;
end;

function ExpandEnvVars(Str: string): string;
var
  //BufSize                     : Integer; // size of expanded string
  Regex                       : TPerlRegEx;
  ResultString                : string;
  EnvVarValue                 : string;
begin
  EnvVarValue := ''; //default
  Result := ''; //default
  Regex := TPerlRegEx.Create();
  try
    Regex.RegEx := '^.*?%(.*?)%.*$';
    Regex.Options := [preCaseless, preMultiLine];
    Regex.Subject := Str;
    if Regex.Match then
    begin
      ResultString := Regex.Groups[1];

      if SameText('ProgramFiles', ResultString) then
      begin
        EnvVarValue := GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows\CurrentVersion',
          'ProgramFilesDir');
      end
      else if SameText('ProgramFiles(x86)', ResultString) then
      begin
        EnvVarValue := GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows\CurrentVersion',
          'ProgramFilesDir (x86)');
      end
      else if SameText('ProgramW6432', ResultString) then
      begin
        EnvVarValue := GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows\CurrentVersion',
          'ProgramW6432Dir');
      end
      else if SameText('CommonProgramFiles', ResultString) then
      begin
        EnvVarValue := GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows\CurrentVersion',
          'CommonFilesDir');
      end
      else if SameText('CommonProgramFiles(x86)', ResultString) then
      begin
        EnvVarValue := GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows\CurrentVersion',
          'CommonFilesDir (x86)');
      end
      else if SameText('CommonProgramW6432', ResultString) then
      begin
        EnvVarValue := GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows\CurrentVersion',
          'CommonW6432Dir');
      end
      else if SameText('windir', ResultString) then
      begin
        EnvVarValue := GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows NT\CurrentVersion',
          'SystemRoot');
      end
      else if SameText('SystemRoot', ResultString) then
      begin
        EnvVarValue := GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows NT\CurrentVersion',
          'SystemRoot');
      end
      else if SameText('SystemDrive', ResultString) then
      begin
        EnvVarValue := ExtractFileDrive(GetRegistryData(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\Microsoft\Windows NT\CurrentVersion', 'SystemRoot'));
      end;
    end
    else
    begin
      ResultString := '';
    end;

    if Length(EnvVarValue) > 0 then
    begin
      Result := ReplaceText(Str, '%' + ResultString + '%',
        ExcludeTrailingPathDelimiter(EnvVarValue));
    end;

  finally
    FreeAndNil(Regex);
  end;
end;

procedure GetProfileList(var slProfileList: TStringList);
var
  Reg                         : TRegistry;
  sCurSid                     : string;
  sCurProfilePath             : string;
  slLocalProfileList          : TStringList;
begin

  Reg := Registry.TRegistry.Create(KEY_READ);
  slLocalProfileList := TStringList.Create;
  try
    Reg.RootKey := Windows.HKEY_LOCAL_MACHINE;
    //if Reg.RegistryConnect(sMachine) then
    begin
      if Reg.KeyExists('SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList') then
      begin
        if Reg.OpenKeyReadOnly('SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList')
          then
        begin
          Reg.GetKeyNames(slLocalProfileList);
          Reg.CloseKey;
        end;

        for sCurSid in slLocalProfileList do
        begin
          if
            Reg.OpenKeyReadOnly('SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\'
            + sCurSid) then
          begin
            if Reg.ValueExists('ProfileImagePath') then
            begin
              //sCurProfilePath := Reg.ReadString('ProfileImagePath');
              sCurProfilePath := Reg.ReadString('ProfileImagePath');
              if ContainsText(sCurProfilePath, '%') then
              begin
                sCurProfilePath := ExpandEnvVars(sCurProfilePath);
              end;
              slProfileList.Add(ExcludeTrailingPathDelimiter(sCurProfilePath));
            end;
            Reg.CloseKey;
          end;
        end;
      end;
    end;
  finally
    FreeAndNil(Reg);
    FreeAndNil(slLocalProfileList);
  end;
end;
end.

