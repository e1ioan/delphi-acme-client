unit ACME.Providers;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  ACME.Types;

type
  TACMEProviders = class(TAcmeObject)
  private
    FStorageFolder: string;
    FProviders: TList<TAcmeProvider>;
    procedure LoadProviders;
    procedure SaveProviders;
    function GetStoragePath: string;
    procedure SetStoragePath(const Value: string);
    procedure LoadDefaultProviders;
  public
    constructor Create(const AStorageFolder: string = ''; AOnLog: TOnLog = nil);
    destructor Destroy; override;

    // Provider management
    function GetKnownProviders: TArray<TAcmeProvider>;
    function GetProviderByName(const AName: string): TAcmeProvider;
    function GetProviderByUrl(const AUrl: string): TAcmeProvider;
    function GetProviderById(const AId: string): TAcmeProvider;
    procedure AddProvider(const AProvider: TAcmeProvider);
    procedure RemoveProvider(const AName: string);
    procedure ClearProviders;
    function GetProviderCount: Integer;

    property StoragePath: string read GetStoragePath write SetStoragePath;
  end;

implementation

{ TACMEProviders }

constructor TACMEProviders.Create(const AStorageFolder: string; AOnLog: TOnLog);
begin
  inherited Create;
  OnLog := AOnLog;
  FProviders := TList<TAcmeProvider>.Create;

  if AStorageFolder <> '' then
    StoragePath := AStorageFolder
  else
    StoragePath := GetDefaultStorageFolder;

  Debug('TACMEProviders initialized with storage path: ' + FStorageFolder);
  LoadProviders;
end;

destructor TACMEProviders.Destroy;
begin
  SaveProviders;
  FProviders.Free;
  inherited;
end;

function TACMEProviders.GetStoragePath: string;
begin
  Result := FStorageFolder;
end;

procedure TACMEProviders.SetStoragePath(const Value: string);
var
  LStorageFolder: string;
begin
  LStorageFolder := Value;
  LStorageFolder := IncludeTrailingPathDelimiter(LStorageFolder);
  if not SameText(FStorageFolder, LStorageFolder) then
  begin
    FStorageFolder := LStorageFolder;
    CheckFolderExists(FStorageFolder, true);
    LoadProviders;
  end;
end;

procedure TACMEProviders.LoadDefaultProviders;
begin
  Log('Loading default ACME providers');
  AddProvider(TAcmeProvider.Create('letsencrypt-production',
    'Let''s Encrypt Production',
    'https://acme-v02.api.letsencrypt.org/directory',
    'Production Let''s Encrypt ACME v2'));
  AddProvider(TAcmeProvider.Create('letsencrypt-staging',
    'Let''s Encrypt Staging',
    'https://acme-staging-v02.api.letsencrypt.org/directory',
    'Staging Let''s Encrypt ACME v2'));
  SaveProviders;
  Log('Default providers loaded successfully');
end;

procedure TACMEProviders.LoadProviders;
var
  LProvidersFile: string;
  LJsonStr: string;
  LJson: TJSONObject;
  LProvidersArray: TJSONArray;
  I: Integer;
  LProvider: TAcmeProvider;
  LProviderObj: TJSONObject;
begin
  FProviders.Clear;

  LProvidersFile := TPath.Combine(FStorageFolder, 'providers.json');
  Debug('Loading providers from: ' + LProvidersFile);

  if not TFile.Exists(LProvidersFile) then
  begin
    Log('Providers file not found, loading defaults');
    LoadDefaultProviders;
    Exit;
  end;

  try
    LJsonStr := TFile.ReadAllText(LProvidersFile, TEncoding.UTF8);
    LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;

    if not Assigned(LJson) then
    begin
      // JSON parsing failed, load defaults
      Log('Failed to parse providers file, loading defaults');
      LoadDefaultProviders;
      Exit;
    end;

    try
      LProvidersArray := LJson.GetValue<TJSONArray>('providers');
      if Assigned(LProvidersArray) then
      begin
        for I := 0 to LProvidersArray.Count - 1 do
        begin
          LProviderObj := LProvidersArray.Items[I] as TJSONObject;
          LProvider.Id := LProviderObj.GetValue<string>('id');
          LProvider.Name := LProviderObj.GetValue<string>('name');
          LProvider.DirectoryUrl := LProviderObj.GetValue<string>
            ('directoryUrl');
          LProvider.Description := LProviderObj.GetValue<string>('description');
          FProviders.Add(LProvider);
          Debug('Loaded provider: ' + LProvider.Name + ' (' +
            LProvider.Id + ')');
        end;
        Log('Loaded ' + IntToStr(LProvidersArray.Count) +
          ' provider(s) from file');
      end;
    finally
      LJson.Free;
    end;
  except
    on E: Exception do
    begin
      Log('Error loading providers: ' + E.Message);
      LoadDefaultProviders;
    end;
  end;
end;

procedure TACMEProviders.SaveProviders;
var
  LProvidersFile: string;
  LJson: TJSONObject;
  LProvidersArray: TJSONArray;
  I: Integer;
  LProviderObj: TJSONObject;
  LProvider: TAcmeProvider;
  LJsonStr: string;
begin
  LProvidersFile := TPath.Combine(FStorageFolder, 'providers.json');
  Debug('Saving ' + IntToStr(FProviders.Count) + ' provider(s) to: ' +
    LProvidersFile);

  LJson := TJSONObject.Create;
  try
    LProvidersArray := TJSONArray.Create;
    for I := 0 to FProviders.Count - 1 do
    begin
      LProvider := FProviders[I];
      LProviderObj := TJSONObject.Create;
      LProviderObj.AddPair('id', LProvider.Id);
      LProviderObj.AddPair('name', LProvider.Name);
      LProviderObj.AddPair('directoryUrl', LProvider.DirectoryUrl);
      LProviderObj.AddPair('description', LProvider.Description);
      LProvidersArray.AddElement(LProviderObj);
    end;
    LJson.AddPair('providers', LProvidersArray);

    LJsonStr := LJson.ToString;
    TFile.WriteAllText(LProvidersFile, LJsonStr, TEncoding.UTF8);
    Debug('Providers saved successfully');
  finally
    LJson.Free;
  end;
end;

function TACMEProviders.GetKnownProviders: TArray<TAcmeProvider>;
var
  I: Integer;
begin
  SetLength(Result, FProviders.Count);
  for I := 0 to FProviders.Count - 1 do
    Result[I] := FProviders[I];
end;

function TACMEProviders.GetProviderByName(const AName: string): TAcmeProvider;
var
  I: Integer;
begin
  Result.Id := '';
  Result.Name := '';
  Result.DirectoryUrl := '';
  Result.Description := '';

  Debug('Looking up provider by name: ' + AName);
  for I := 0 to FProviders.Count - 1 do
  begin
    if SameText(FProviders[I].Name, AName) then
    begin
      Result := FProviders[I];
      Debug('Found provider: ' + Result.Id);
      Exit;
    end;
  end;
  Debug('Provider not found by name: ' + AName);
end;

function TACMEProviders.GetProviderByUrl(const AUrl: string): TAcmeProvider;
var
  I: Integer;
begin
  Result.Id := '';
  Result.Name := '';
  Result.DirectoryUrl := '';
  Result.Description := '';

  for I := 0 to FProviders.Count - 1 do
  begin
    if SameText(FProviders[I].DirectoryUrl, AUrl) then
    begin
      Result := FProviders[I];
      Exit;
    end;
  end;
end;

function TACMEProviders.GetProviderById(const AId: string): TAcmeProvider;
var
  I: Integer;
begin
  Result.Id := '';
  Result.Name := '';
  Result.DirectoryUrl := '';
  Result.Description := '';

  Debug('Looking up provider by ID: ' + AId);
  for I := 0 to FProviders.Count - 1 do
  begin
    if SameText(FProviders[I].Id, AId) then
    begin
      Result := FProviders[I];
      Debug('Found provider: ' + Result.Name);
      Exit;
    end;
  end;
  Debug('Provider not found by ID: ' + AId);
end;

procedure TACMEProviders.AddProvider(const AProvider: TAcmeProvider);
begin
  Debug('Adding provider: ' + AProvider.Name + ' (' + AProvider.Id + ')');
  // Check if provider already exists by ID
  if GetProviderById(AProvider.Id).Id <> '' then
  begin
    Log('Provider with ID "' + AProvider.Id + '" already exists');
    raise Exception.Create('Provider with ID "' + AProvider.Id +
      '" already exists');
  end;

  FProviders.Add(AProvider);
  SaveProviders;
  Log('Provider added: ' + AProvider.Name);
end;

procedure TACMEProviders.RemoveProvider(const AName: string);
var
  I: Integer;
begin
  Debug('Removing provider: ' + AName);
  for I := FProviders.Count - 1 downto 0 do
  begin
    if SameText(FProviders[I].Name, AName) then
    begin
      Log('Provider removed: ' + FProviders[I].Name + ' (' + FProviders[I]
        .Id + ')');
      FProviders.Delete(I);
      SaveProviders;
      Exit;
    end;
  end;
  Debug('Provider not found for removal: ' + AName);
end;

procedure TACMEProviders.ClearProviders;
begin
  Log('Clearing all providers');
  FProviders.Clear;
  SaveProviders;
  Log('All providers cleared');
end;

function TACMEProviders.GetProviderCount: Integer;
begin
  Result := FProviders.Count;
end;

end.
