unit xxmEditProject;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Menus, jsonDoc, ComCtrls, StdCtrls, Dialogs, ImgList, ActnList;

type
  TEditProjectMainForm = class(TForm)
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    New1: TMenuItem;
    Save1: TMenuItem;
    N1: TMenuItem;
    Exit1: TMenuItem;
    odOpenProject: TOpenDialog;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    Label1: TLabel;
    txtProjectName: TEdit;
    Label2: TLabel;
    txtCompileCommand: TEdit;
    tvFiles: TTreeView;
    Open1: TMenuItem;
    btnRegisterLocal: TButton;
    ImageList1: TImageList;
    PopupMenu1: TPopupMenu;
    ActionList1: TActionList;
    Include1: TMenuItem;
    Exclude1: TMenuItem;
    actInclude: TAction;
    actExclude: TAction;
    N2: TMenuItem;
    actDelete: TAction;
    Delete1: TMenuItem;
    ree1: TMenuItem;
    Include2: TMenuItem;
    Exclude2: TMenuItem;
    N3: TMenuItem;
    Delete2: TMenuItem;
    actRefresh: TAction;
    N4: TMenuItem;
    Refresh1: TMenuItem;
    actIncludePas: TAction;
    odIncludeUnit: TOpenDialog;
    Includeunit2: TMenuItem;
    StatusBar1: TStatusBar;
    btnRegisterFile: TButton;
    odXxmJson: TOpenDialog;
    TabSheet3: TTabSheet;
    cbParserValue: TComboBox;
    txtParserValue: TMemo;
    Label3: TLabel;
    Label4: TLabel;
    procedure Exit1Click(Sender: TObject);
    procedure txtChange(Sender: TObject);
    procedure tvFilesCreateNodeClass(Sender: TCustomTreeView;
      var NodeClass: TTreeNodeClass);
    procedure New1Click(Sender: TObject);
    procedure Save1Click(Sender: TObject);
    procedure Open1Click(Sender: TObject);
    procedure btnRegisterLocalClick(Sender: TObject);
    procedure tvFilesExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
    procedure tvFilesCompare(Sender: TObject; Node1, Node2: TTreeNode;
      Data: Integer; var Compare: Integer);
    procedure tvFilesDblClick(Sender: TObject);
    procedure actDeleteExecute(Sender: TObject);
    procedure tvFilesContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure actIncludeExecute(Sender: TObject);
    procedure actExcludeExecute(Sender: TObject);
    procedure tvFilesChange(Sender: TObject; Node: TTreeNode);
    procedure actRefreshExecute(Sender: TObject);
    procedure actIncludePasExecute(Sender: TObject);
    procedure btnRegisterFileClick(Sender: TObject);
    procedure cbParserValueChange(Sender: TObject);
    procedure txtParserValueChange(Sender: TObject);
  private
    Modified:boolean;
    ProjectPath,ProjectFolder:AnsiString;
    ProjectData:IJSONDocument;
    LastParserValue:integer;
    function CheckModified:boolean;
    function LoadProject(const Path:AnsiString;CreateNew:boolean):boolean;
    procedure SaveProject;
    procedure ExpandNode(node:TTreeNode);
    procedure SaveParserValue;
  protected
    procedure DoCreate; override;
    procedure DoClose(var Action: TCloseAction); override;
  public

  end;

  TFileNode=class(TTreeNode)
  public
    IsDir:boolean;
    Col,Key:string;
    Doc:IJSONDocument;
  end;

const
  ApplicationTitle='xxm Project Properties';

var
  EditProjectMainForm: TEditProjectMainForm;

implementation

uses DateUtils, xxmUtilities, Registry, ShellAPI, ComObj, xxmConvertXML,
  xxmConvert2;

{$R *.dfm}

procedure TEditProjectMainForm.DoCreate;
var
  s:AnsiString;
begin
  inherited;
  ProjectData:=JSON;
  if ParamCount=0 then
   begin
    if not(LoadProject('',false)) then Application.Terminate;
   end
  else
   begin
    s:=ParamStr(1);
    if LowerCase(s)='/n' then s:=ExtractFilePath(ParamStr(2))+XxmProjectFileName;
    LoadProject(s,false);
   end;
  //assert Modified=false
  PageControl1.Align:=alClient;//fix!
end;

procedure TEditProjectMainForm.Exit1Click(Sender: TObject);
begin
  Close;
end;

function TEditProjectMainForm.CheckModified: boolean;
begin
  Result:=true;
  if Modified then
    case MessageBox(Handle,'Save changes first?',ApplicationTitle,MB_YESNOCANCEL or MB_ICONQUESTION) of
      idYes:SaveProject;
      idNo:;
      idCancel:Result:=false;
    end;
end;

function TEditProjectMainForm.LoadProject(const Path: AnsiString;
  CreateNew: boolean): boolean;
var
  f:TFileStream;
  fn,fd:AnsiString;
  fe:boolean;
  i,j:integer;
begin
  //assert CheckModified called before

  if Path='' then
   begin
    Result:=CreateNew or odOpenProject.Execute;
    if Result then
     begin
      fn:=odOpenProject.FileName;
      SetForegroundWindow(Handle);
     end;
   end
  else
   begin
    Result:=true;//?
    fn:=Path;
    //Path could be by parameter, so resolve and expand
    if DirectoryExists(fn) then fn:=IncludeTrailingPathDelimiter(fn)+XxmProjectFileName;
   end;

  if Result then
   begin
    fe:=GetFileSize(fn)>0;
    if fe then
     begin

      f:=TFileStream.Create(fn,fmOpenRead or fmShareDenyWrite);
      try
        //TODO: support UTF8,UTF16
        i:=f.Size;
        SetLength(fd,i);
        f.Read(fd[1],i);
      finally
        f.Free;
      end;

      //TRANSITIONAL
      if (i<>0) and (fd[1]='<') then fd:=ConvertProjectFile(fd);

      ProjectData.Parse(fd);
     end
    else
     begin
      j:=Length(fn);
      while (j<>0) and (fn[j]<>PathDelim) do dec(j);
      i:=j-1;
      while (i>0) and (fn[i]<>PathDelim) do dec(i);
      ProjectData['name']:=Copy(fn,i+1,j-i-1);
      ProjectData['compileCommand']:='dcc32 -U[[HandlerPath]]public -Q [[ProjectName]].dpr';
      ProjectData['files']:=JSON;
      ProjectData['units']:=JSON;
      ProjectData['resources']:=JSON;
      //'UUID' here?
     end;
    ProjectPath:=fn;
    Caption:='xxm Project - '+fn;
    Application.Title:='xxm Project - '+fn;

    txtProjectName.Text:=VarToStr(ProjectData['name']);
    txtCompileCommand.Text:=VarToStr(ProjectData['compileCommand']);//TODO: support array of strings
    LastParserValue:=-1;
    cbParserValue.ItemIndex:=-1;

    i:=Length(ProjectPath);
    while (i<>0) and (ProjectPath[i]<>PathDelim) do dec(i);
    ProjectFolder:=Copy(ProjectPath,1,i);

    //load files
    ExpandNode(nil);

    Modified:=not(fe);
   end;
end;

procedure TEditProjectMainForm.SaveProject;
var
  s:AnsiString;
  f:TFileStream;
begin
  if txtProjectName.Text='' then raise Exception.Create('Project name required');
  SaveParserValue;
  ProjectData['name']:=txtProjectName.Text;
  ProjectData['compileCommand']:=txtCompileCommand.Text;//TODO: support array of strings
  ProjectData['lastModified']:=
    FormatDateTime('yyyy-mm-dd"T"hh:nn:ss',Now);//timezone?
  //TODO: files?
  s:=ProjectData.ToString;
  f:=TFileStream.Create(ProjectPath,fmCreate);
  try
    f.Write(s[1],Length(s));//TODO: UTF8
  finally
    f.Free;
  end;
  Modified:=false;
end;

procedure TEditProjectMainForm.txtChange(Sender: TObject);
begin
  Modified:=true;
end;

procedure TEditProjectMainForm.DoClose(var Action: TCloseAction);
begin
  inherited;
  if not(CheckModified) then Action:=caNone;
end;

procedure TEditProjectMainForm.tvFilesCreateNodeClass(
  Sender: TCustomTreeView; var NodeClass: TTreeNodeClass);
begin
  NodeClass:=TFileNode;
end;

procedure TEditProjectMainForm.New1Click(Sender: TObject);
begin
  if CheckModified then LoadProject('',true);
end;

procedure TEditProjectMainForm.Save1Click(Sender: TObject);
begin
  SaveProject;
end;

procedure TEditProjectMainForm.Open1Click(Sender: TObject);
begin
  if CheckModified then LoadProject('',false);
end;

procedure TEditProjectMainForm.btnRegisterLocalClick(Sender: TObject);
var
  r:TRegistry;
  s,t,u:AnsiString;
begin
  if CheckModified then
   begin
    t:=txtProjectName.Text;
    if t='' then raise Exception.Create('Project name required');
    s:=ProjectFolder+t+'.xxl';
    r:=TRegistry.Create;
    try
      r.RootKey:=HKEY_CURRENT_USER;//HKEY_LOCAL_MACHINE;
      r.OpenKey('\Software\xxm\local\'+t,true);
      u:=r.ReadString('');
      if (u='') or (u=s) or (MessageBoxA(GetDesktopWindow,PAnsiChar('Project "'+t+
        '" was already registered as'#13#10'  '+u+
        #13#10'Do you want to overwrite this registration?'#13#10'  '+s),
        'xxm Project',MB_OKCANCEL or MB_ICONQUESTION or MB_SYSTEMMODAL)=idOK) then
       begin
        r.WriteString('',s);
        r.DeleteValue('Signature');
        //TODO: default settings?
        MessageBoxA(GetDesktopWindow,PAnsiChar('Project "'+t+'" registered.'),
          'xxm Project',MB_OK or MB_ICONINFORMATION);
       end;
    finally
      r.Free;
    end;
   end;
end;

const
  iiDir=0;
  iiDirIncluded=1;
  iiDirGenerated=2;
  iiFile=3;
  iiFileIncluded=4;
  iiFileGenerated=5;
  iiPas=6;
  iiPasIncluded=7;
  iiPasGenerated=8;
  iiDpr=9;
  iiXxm=10;
  iiXxmi=11;
  iiXxmp=12;
  iiXxl=13;

procedure TEditProjectMainForm.ExpandNode(node: TTreeNode);
var
  fh:THandle;
  fd:TWin32FindDataA;
  d,fn,fe,dx,fx:AnsiString;
  ft:TXxmFileType;
  nn:TTreeNode;
  n:TFileNode;
  i:integer;
  x:IJSONDocument;
  y:IJSONEnumerator;
begin
  tvFiles.Items.BeginUpdate;
  try
    tvFiles.SortType:=stNone;
    if node=nil then tvFiles.Items.Clear else node.DeleteChildren;
    d:='';
    nn:=node;
    while nn<>nil do
     begin
      d:=nn.Text+PathDelim+d;
      nn:=nn.Parent;
     end;
    fh:=FindFirstFileA(PAnsiChar(ProjectFolder+d+'*.*'),fd);
    if fh<>INVALID_HANDLE_VALUE then
      try
        repeat
          if ((fd.dwFileAttributes and FILE_ATTRIBUTE_HIDDEN)=0) and
             ((fd.dwFileAttributes and FILE_ATTRIBUTE_SYSTEM)=0) then
            if (fd.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY)=0 then
             begin
              //file
              n:=tvFiles.Items.AddChild(node,fd.cFileName) as TFileNode;
              n.IsDir:=false;
              n.Col:='';
              n.Key:='';
              n.Doc:=nil;
              fn:=fd.cFileName;
              i:=Length(fn);
              while (i<>0) and (fn[i]<>'.') do dec(i);
              if i=0 then fe:='' else fe:=LowerCase(Copy(fn,i,Length(fn)-i+1));
              if fe=DelphiExtension then //.pas
                if LowerCase(fn)=ProtoProjectPas then //xxmp.pas
                  n.ImageIndex:=iiPasGenerated
                else
                 begin
                  fx:=Copy(fn,1,i-1);
                  dx:=StringReplace(d,'\','\\',[rfReplaceAll]);
                  x:=nil;
                  y:=JSONEnum(ProjectData['units']);
                  while (x=nil) and y.Next do
                   begin
                    x:=JSON(y.Value);
                    if not((VarToStr(x['unitName'])=fx) and
                      (VarToStr(x['unitPath'])=dx)) then
                     begin
                      n.Col:='files';
                      n.Key:=y.Key;
                      n.Doc:=x;
                      n.ImageIndex:=iiPasIncluded;
                     end
                    else
                      x:=nil;
                   end;
                  if x=nil then n.ImageIndex:=iiPas;
                 end
              else if fe=DelphiProjectExtension then //.dpr
                n.ImageIndex:=iiDpr
              else if (fe='.cfg') or (fe='.dof') then
                n.ImageIndex:=iiFileGenerated
              else
               begin
                ft:=TXxmFileType(0);
                while (ft<>ft_Unknown) and (fe<>XxmFileExtension[ft]) do inc(ft);
                case ft of
                  ftPage,ftInclude:
                   begin
                    dx:=StringReplace(d,'\','\\',[rfReplaceAll])+Copy(fn,1,i-1);
                    x:=nil;
                    y:=JSONEnum(ProjectData['files']);
                    while (x=nil) and y.Next do
                     begin
                      x:=JSON(y.Value);
                      if VarToStr(x['path'])=dx then
                       begin
                        n.Col:='files';
                        n.Key:=y.Key;
                        n.Doc:=x;
                       end
                      else
                        x:=nil;
                     end;
                    if ft=ftPage then
                      n.ImageIndex:=iiXxm
                    else
                      n.ImageIndex:=iiXxmi;
                   end;
                  ftProject://.xxmp
                   begin
                    n.ImageIndex:=iiXxmp;
                    //TODO: invalidate folder since it's another project
                   end;
                  ft_Unknown:
                   begin
                    dx:=StringReplace(d,'\','\\',[rfReplaceAll])+fn;
                    x:=JSON(JSON(ProjectData['resources'])[dx]);
                    n.Col:='resources';
                    n.Key:=dx;
                    n.Doc:=x;
                    if x=nil then
                      n.ImageIndex:=iiFile
                    else
                      n.ImageIndex:=iiFileIncluded;
                   end;
                end;
               end;
              n.SelectedIndex:=n.ImageIndex;
             end
            else
             begin
              //directory
              if (fd.cFileName[0]<>'.') then
               begin
                fn:=fd.cFileName;
                n:=tvFiles.Items.AddChild(node,fn) as TFileNode;
                n.IsDir:=true;
                n.Col:='';
                n.Key:='';
                n.Doc:=nil;
                if ((node=nil) and ((fn=SourceDirectory) or (fn=ProtoDirectory))) or
                   ((n.Parent<>nil) and (n.Parent.ImageIndex=iiDirGenerated)) then
                 begin
                  n.ImageIndex:=iiDirGenerated;
                  //n.HasChildren:=true;
                  //TODO: map generated pas files on <Unit> tags
                 end
                else
                 begin
                  n.ImageIndex:=iiDir;
                  n.HasChildren:=true;
                 end;
                //ProtoDirectory?
                n.SelectedIndex:=n.ImageIndex;
               end;
             end;
        until not(FindNextFileA(fh,fd));
      finally
        Windows.FindClose(fh);
      end;
    tvFiles.SortType:=stData;
  finally
    tvFiles.Items.EndUpdate;
  end;
  //TODO: merge (missing) XML items?
end;

procedure TEditProjectMainForm.tvFilesExpanding(Sender: TObject;
  Node: TTreeNode; var AllowExpansion: Boolean);
begin
  ExpandNode(Node);
end;

procedure TEditProjectMainForm.tvFilesCompare(Sender: TObject; Node1,
  Node2: TTreeNode; Data: Integer; var Compare: Integer);
begin
  Compare:=0;
  if (Node1 as TFileNode).IsDir then dec(Compare);
  if (Node2 as TFileNode).IsDir then inc(Compare);
  if Compare=0 then Compare:=AnsiCompareText(Node1.Text,Node2.Text);
end;

procedure TEditProjectMainForm.tvFilesDblClick(Sender: TObject);
begin
  if actInclude.Enabled then actInclude.Execute;
end;

procedure TEditProjectMainForm.actDeleteExecute(Sender: TObject);
var
  so:TSHFileOpStructA;
  n,nx:TTreeNode;
  s:AnsiString;
begin
  nx:=tvFiles.Selected;
  n:=nx;
  s:='';
  while n<>nil do
   begin
    s:=s+PathDelim+n.Text;
    n:=n.Parent;
   end;
  so.Wnd:=Handle;
  so.wFunc:=FO_DELETE;
  so.pFrom:=PAnsiChar(ProjectFolder+Copy(s,2,Length(s)-1));
  so.pTo:=nil;
  so.fFlags:=FOF_ALLOWUNDO;
  so.fAnyOperationsAborted:=false;
  so.hNameMappings:=nil;
  so.lpszProgressTitle:=nil;
  OleCheck(SHFileOperationA(so));
  if not(so.fAnyOperationsAborted) then
   begin
    JSON(ProjectData[(nx as TFileNode).Col])[(nx as TFileNode).Key]:=Null;
    nx.Delete;
   end;
end;

procedure TEditProjectMainForm.tvFilesContextPopup(Sender: TObject;
  MousePos: TPoint; var Handled: Boolean);
begin
  //odd, RightClickSelect doesn't work...
  //Handled:=false;
  tvFiles.Selected:=tvFiles.GetNodeAt(MousePos.X,MousePos.Y);

  //case (n as TFileNode). of
end;

procedure TEditProjectMainForm.actIncludeExecute(Sender: TObject);
var
  n,nx:TTreeNode;
  nn:TFileNode;
  s:AnsiString;
  i,j:integer;
begin
  n:=tvFiles.Selected;
  nx:=n;
  s:='';
  while nx<>nil do
   begin
    s:=PathDelim+nx.Text+s;
    nx:=nx.Parent;
   end;
  nn:=n as TFileNode;
  case n.ImageIndex of
    iiPas:
     begin
      i:=Length(s);
      while (i<>0) and (s[i]<>'.') do dec(i);
      j:=i;
      while (j<>0) and (s[j]<>PathDelim) do dec(j);
      nn.ImageIndex:=iiPasIncluded;
      nn.Col:='units';
      nn.Key:=Copy(s,j+1,i-j-1);
      nn.Doc:=JSON;
      if j>1 then nn.Doc['unitPath']:=Copy(s,2,j-1);
      JSON(ProjectData[nn.Col])[nn.Key]:=nn.Doc;
      Modified:=true;
     end;
    iiFile:
     begin
      nn.ImageIndex:=iiFileIncluded;
      nn.Col:='resources';
      nn.Key:=Copy(s,2,Length(s));
      nn.Doc:=JSON;
      JSON(ProjectData[nn.Col])[nn.Key]:=nn.Doc;
      Modified:=true;
     end;
    //more?
  end;
  nn.SelectedIndex:=nn.ImageIndex;
  tvFilesChange(tvFiles,n);
end;

procedure TEditProjectMainForm.actExcludeExecute(Sender: TObject);
var
  n:TFileNode;
begin
  n:=tvFiles.Selected as TFileNode;
  //case (n of TFileNode) of
  case n.ImageIndex of
    iiPasIncluded,iiFileIncluded:
     begin
      JSON(ProjectData[n.Col])[n.Key]:=Null;
      n.Doc:=nil;
      n.ImageIndex:=n.ImageIndex-1;
      n.SelectedIndex:=n.ImageIndex;
      Modified:=true;
     end;
    //more?
  end;
  tvFilesChange(tvFiles,n);
end;

procedure TEditProjectMainForm.tvFilesChange(Sender: TObject;
  Node: TTreeNode);
var
  n:TTreeNode;
  s:string;
begin
  n:=tvFiles.Selected;
  actInclude.Enabled:=(n<>nil) and (n.ImageIndex in [iiPas,iiFile]);
  actExclude.Enabled:=(n<>nil) and (n.ImageIndex in [iiPasIncluded,iiFileIncluded]);
  actDelete.Enabled:=(n<>nil);
  s:='';
  while n<>nil do
   begin
    s:='\'+n.Text+s;
    n:=n.Parent;
   end;
  StatusBar1.Panels[0].Text:=Copy(s,2,Length(s));
end;

procedure TEditProjectMainForm.actRefreshExecute(Sender: TObject);
begin
  ExpandNode(nil);
end;

procedure TEditProjectMainForm.actIncludePasExecute(Sender: TObject);
var
  x:IJSONDocument;
  y:IJSONEnumerator;
  s,t,u:AnsiString;
  i,j,l,fi,fl,fc:integer;
begin
  if odIncludeUnit.Execute then
   begin
    fc:=0;
    fl:=odIncludeUnit.Files.Count;
    for fi:=0 to fl-1 do
     begin
      s:=odIncludeUnit.Files[fi];
      if LowerCase(Copy(s,1,Length(ProjectFolder)))=LowerCase(ProjectFolder) then
        raise Exception.Create('Use include on a tree node to include a file in the project folder.');//TODO
      //build relative to ProjectFolder
      l:=Length(ProjectFolder);
      j:=Length(s);
      i:=1;
      while (i<=l) and (i<=j) and (UpCase(s[i])=UpCase(ProjectFolder[i])) do inc(i);
      while (i>0) and (s[i]<>PathDelim) do dec(i);
      //assert (i<=l)
      s:=Copy(s,i+1,j-i);
      inc(i);
      while i<=l do
       begin
        if ProjectFolder[i]=PathDelim then s:='..'+PathDelim+s;
        inc(i);
       end;
      //strip extension, path
      i:=Length(s);
      while (i<>0) and (s[i]<>'.') do dec(i);
      j:=i;
      while (j<>0) and (s[j]<>PathDelim) do dec(j);

      t:=Copy(s,j+1,i-j-1);//unitName
      u:=Copy(s,1,j);//unitPath

      x:=nil;
      y:=JSONEnum(ProjectData['files']);
      while (x=nil) and y.Next do
       begin
        x:=JSON(y.Value);
        if (VarToStr(x['unitName'])=t) and ((j=0) or (VarToStr(x['unitPath'])=u)) then
         begin
          if fl=1 then MessageBoxA(Handle,PAnsiChar(
            'Unit "'+s+'" is aready added to the project'),
            'xxm Project',MB_OK or MB_ICONERROR);
         end
        else
          x:=nil;
       end;
      if x=nil then
       begin
        x:=JSON(['unitName',t]);
        if j<>0 then x['unitPath']:=u;
        //(n as TFileNode).ProjectNode:=x;
        Modified:=true;
        inc(fc);
        if fl=1 then MessageBoxA(Handle,PAnsiChar('Unit "'+s+'" added'),
          'xxm Project',MB_OK or MB_ICONINFORMATION);
       end;
     end;
    if fl>1 then MessageBoxA(Handle,PAnsiChar(IntToStr(fc)+' units added'),
      'xxm Project',MB_OK or MB_ICONINFORMATION);
   end;
end;

procedure TEditProjectMainForm.btnRegisterFileClick(Sender: TObject);
var
  fn,s,t,u:AnsiString;
  i:integer;
  f:TFileStream;
  d,d1:IJSONDocument;
const
  Utf8ByteOrderMark=#$EF#$BB#$BF;
begin
  if CheckModified then
   begin
    t:=txtProjectName.Text;
    if t='' then raise Exception.Create('Project name required');
    s:=ProjectFolder+t+'.xxl';
    if odXxmJson.Execute then
     begin
      fn:=odXxmJson.FileName;
      //TRANSITIONAL
      if LowerCase(Copy(fn,Length(fn)-3,4))='.xml' then
       begin
        s:=GetCurrentDir;
        SetCurrentDir(ExtractFilePath(fn));
        ConvertProjectReg;
        SetCurrentDir(s);
        fn:=Copy(fn,1,Length(fn)-4)+'.json';
       end;

      d:=JSON;
      if FileExists(fn) then
       begin
        f:=TFileStream.Create(fn,fmOpenRead or fmShareDenyWrite);
        try
          i:=f.Size;
          SetLength(u,i);
          if i<>f.Read(u[1],i) then RaiseLastOSError;
          if (i>=3) and (u[1]=#$EF) and (u[2]=#$BB) and (u[3]=#$BF) then
            d.Parse(UTF8Decode(Copy(u,4,i-3)))
          else
          if (i>=2) and (u[1]=#$FF) and (u[2]=#$FE) then
            d.Parse(PWideChar(@u[1]))
          else
            d.Parse(WideString(u));
        finally
          f.Free;
        end;
       end
      else
        d['projects']:=JSON;
      d1:=JSON(JSON(d['projects'])[t]);
      if d1=nil then u:='' else u:=VarToStr(d1['path']);
      if (u='') or (u=s) or (MessageBoxA(GetDesktopWindow,PAnsiChar('Project "'+t+
        '" was already registered as'#13#10'  '+u+
        #13#10'Do you want to overwrite this registration?'#13#10'  '+s),
        'xxm Project',MB_OKCANCEL or MB_ICONQUESTION or MB_SYSTEMMODAL)=idOK) then
       begin
        if d1=nil then
         begin
          d1:=JSON;
          JSON(d['projects'])[t]:=d1;
         end
        else
         begin
          d1['signature']:=Null;
          d1['alias']:=Null;//?
         end;
        d1['path']:=s;
        s:=Utf8ByteOrderMark+UTF8Encode(d.ToString);
        f:=TFileStream.Create(fn,fmCreate);
        try
          f.Write(s[1],Length(s));
        finally
          f.Free;
        end;
        MessageBoxA(GetDesktopWindow,PAnsiChar('Project "'+t+'" registered with "'+fn+'".'),
          'xxm Project',MB_OK or MB_ICONINFORMATION);
       end;
     end;
   end;
end;

const
  ParserValueElement:array[0..15] of string=(
    'SendOpen','SendClose',
    'SendHTMLOpen','SendHTMLClose',
    'URLEncodeOpen','URLEncodeClose',
    'Extra1Open','Extra1Close',
    'Extra2Open','Extra2Close',
    'Extra3Open','Extra3Close',
    'Extra4Open','Extra4Close',
    'Extra5Open','Extra5Close'
  );

procedure TEditProjectMainForm.cbParserValueChange(Sender: TObject);
var
  d:IJSONDocument;
begin
  if cbParserValue.ItemIndex=-1 then
    txtParserValue.Text:=''
  else
   begin
    SaveParserValue;
    d:=JSON(ProjectData['parserValues']);
    txtParserValue.Text:=VarToStr(
      d[ParserValueElement[cbParserValue.ItemIndex]]);
   end;
  //txtParserValue.Modified:=false;
  LastParserValue:=cbParserValue.ItemIndex;
end;

procedure TEditProjectMainForm.txtParserValueChange(Sender: TObject);
begin
  Modified:=true;
end;

procedure TEditProjectMainForm.SaveParserValue;
var
  d:IJSONDocument;
begin
  if LastParserValue<>-1 then
   begin
    d:=JSON(ProjectData['parserValues']);
    if txtParserValue.Text='' then
      d[ParserValueElement[LastParserValue]]:=Null
    else
      d[ParserValueElement[LastParserValue]]:=txtParserValue.Text;
   end;
end;

end.
