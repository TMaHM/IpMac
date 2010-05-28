{
2009-11-25 v1.2
    + ��������IP��ʶ
    + ����IP�����ñ��湦��(һ���û����)
    * �ڲ�����ЩС�Ż�,Ҳ��С���ڴ�ռ��(�����Ͳ���)

2009-4-21 v1.1
    ��1.0�Ļ����϶Ժܶ�ϸ�ڽ����Ż���
    ����IP��MAC�ɼ��浵,��MAC��ַ�����ʾ������������ʾ��
    ���뻽����ʱ�Ͷ��߳̽�������
    ��ȡ�������㷨�Ľ��������������
    ...

2009-4-19 v1.0
    ʵ��IP-MAC���߳�ɨ������绽�ѹ��ܡ�

}
unit IpMacUnit;

interface
uses
  Windows,
  Messages,
  Sysutils,
  WINSOCK,
  KOL,
  NetAPIUnit;

procedure ApplicationRun;
implementation
const
  Conf              = 'IPMac.txt';
  BTN_START         = '��ʼ(&S)';
  BTN_STOP          = 'ֹͣ(&S)';
  STATUS_DOWN       = '��';
  STATUS_UP         = '��';
  MAC_YES           = 'Yes';
  MAC_NO            = 'No';
  MAC_NEW           = 'New';
  TITLE_SCAN        = 'ɨ��';
  TITLE_WAKEUP      = '����';
  TITLE_LOAD        = '����';

var
  W                 : pControl;
  gSet, iEdit1, iEdit2, iEdit3, Label1, StartBtn, ClearBtn: pControl;
  gScanList, ListView: pControl;
  PopupMenu         : PMenu;

  TF_stop           : boolean = true;   {ֹͣ}
  ThID              : DWORD;
  StartTickCount    : DWORD;            {������}
  StopTickCount     : DWORD;
  StartIP, ScanIPCount, StartHostID: DWORD;
  ThreadCount       : DWORD = 10;       //�߳�����
  ThreadTick        : DWORD;            //�߳��˳��ͼ�һ ,ȫ���˳������
  LVCri             : TRTLCriticalSection;
  isChange          : Boolean = false;
  cfgfile           : string;

function StrDec(const Str: string): string;
const
  XorKey            : array[0..7] of Byte = ($B2, $09, $AA, $55, $93, $6D, $84, $47);
var
  i, j              : Integer;
begin
  result := '';
  j := 0;
  try
    for i := 1 to Length(Str) div 2 do begin
      result := result + Char(StrToInt('$' + copy(Str, i * 2 - 1, 2)) xor XorKey[j]);
      j := (j + 1) mod 8;
    end;
  except
  end;
end;

procedure MakeEnd(const Title: string; const Num: DWORD);
var
  Str               : string;
  i, n, j           : DWORD;
begin
  j := 0;
  n := Num;
  TF_stop := true;
  StartBtn.caption := BTN_START;
  StopTickCount := GetTickCount;
  if Title = TITLE_SCAN then begin
    for i := 0 to ListView.Count - 1 do begin
      if ListView.LVItems[i, 5] <> STATUS_DOWN then
        Inc(n);
      if ListView.LVItems[i, 3] <> '0' then
        Inc(j);
    end;
    Str := '��New: ' + IntToStr(j);
  end;
  W.caption := Title + '��ʱ: ' + IntToStr(StopTickCount - StartTickCount) + ' ms��IP: ' + IntToStr(n) + '/' + IntToStr(ListView.Count) + Str;
end;

function ARPScanThread(p: Pointer): Integer;
var
  Str_Ip, Str_MAC   : string;
  Start_IP, IP_now, i, n: DWORD;
begin
  result := 0;
  Start_IP := StartIP;
  n := ScanIPCount div ThreadCount - 1; //ͳһ������
  if (ScanIPCount mod ThreadCount) >= DWORD(p) then //��ʣ�µ�����
    Inc(n);
  for i := 0 to n do begin
    if TF_stop then
      break;
    IP_now := InetHexToInt(IntToHex(Start_IP, 8)) + i * ThreadCount + DWORD(p) - 1; //ת��˳�� ����1
    IP_now := InetHexToInt(IntToHex(IP_now, 8)); //��ԭ����˳��
    Str_Ip := HexToIp(IntToHex(IP_now, 8));
    Str_MAC := GetMacAddr(IP_now);      //SendARP
    EnterCriticalSection(LVCri);        //�����ٽ���
    W.caption := Str_Ip;                //Ŀǰɨ���IP
    with ListView^ do begin
      n := LVIndexOf(MakeID(StartHostID + i * ThreadCount + DWORD(p)));
      if Str_MAC <> '' then begin
        if n < (High(n) + low(n)) then begin
          if (LVItems[n, 2] <> Str_MAC) then begin
            isChange := True;
            LVItems[n, 2] := Str_MAC;   //'����MAC��'
            LVItems[n, 4] := MAC_YES
          end;
        end
        else begin
          isChange := True;
          n := LVItemAdd(MakeID(StartHostID + i * ThreadCount + DWORD(p)));
          LVItems[n, 1] := Str_Ip;      //'TP��ַ'
          LVItems[n, 2] := Str_MAC;     //'����MAC��'
          LVItems[n, 3] := IntToStr(DWORD(p));
          LVItems[n, 4] := MAC_NEW;
        end;
        LVItems[n, 5] := STATUS_UP;
        result := 1;
      end
      else if n < (High(n) + low(n)) then
        LVItems[n, 5] := STATUS_DOWN;
    end;
    LeaveCriticalSection(LVCri);        //�˳��ٽ���
  end;
  if ThreadTick > 1 then
    Dec(ThreadTick)
  else begin                            //�Լ��Ǻ���һ����β�߳�
    DeleteCriticalSection(LVCri);
    MakeEnd(TITLE_SCAN, 0);
  end;
end;

procedure StartScan;
var
  i, DWx1, Dwx      : DWORD;
  Hex_Ip            : string;
begin
  TF_stop := false;
  StartBtn.caption := BTN_STOP;
  if (inet_addr(pchar(trim(iEdit1.Text))) <> INADDR_NONE) and (inet_addr(pchar(trim(iEdit1.Text))) <> INADDR_NONE) then begin
    Hex_Ip := IntToHex(inet_addr(pchar(trim(iEdit1.Text))), 8); //01 00 A8 C0
    Dwx := InetHexToInt(Hex_Ip);        {ת����Ϊһ����������}
    iEdit1.Text := HexToIp(Hex_Ip);     {�������� һ����ֵ��ʾIP}

    Hex_Ip := IntToHex(inet_addr(pchar(trim(iEdit2.Text))), 8); //01 00 A8 C0
    DWx1 := InetHexToInt(Hex_Ip);
    iEdit2.Text := HexToIp(Hex_Ip);

    if DWx1 > Dwx then begin
      ScanIPCount := DWx1 - Dwx + 1;
      StartIP := inet_addr(pchar(trim(iEdit1.Text)));
      Label1.caption := '++>';
      Hex_Ip := IntToHex(inet_addr(pchar(iEdit1.Text)), 8); //01 00 A8 C0
    end
    else begin
      ScanIPCount := Dwx - DWx1 + 1;
      StartIP := inet_addr(pchar(trim(iEdit2.Text)));
      Label1.caption := '<++';
    end;

    ThreadCount := StrToInt(iEdit3.Text);
    StartHostID := GetHostStartID(Hex_Ip) - 1;

    InitializeCriticalSection(LVCri);   //�����ٽ���
    if (ScanIPCount < ThreadCount) or (ThreadCount = 0) then
      ThreadCount := ScanIPCount;
    if ThreadCount > 1000 then
      ThreadCount := 800;
    ThreadTick := ThreadCount;
    StartTickCount := GetTickCount;
    for i := 1 to ThreadCount do begin
      CloseHandle(BeginThread(nil, 0, @ARPScanThread, Pointer(i), 0, ThID));
    end;
  end;
end;

procedure StartWakeUp;
var
  i, n              : Integer;
begin
  n := 0;
  TF_stop := false;
  StartBtn.caption := BTN_STOP;
  StartTickCount := GetTickCount;
  with ListView^ do
    if LVSelCount > 0 then begin
      i := LVCurItem;
      while i > -1 do begin
        if TF_stop then exit;
        W.caption := LVItems[i, 1];
        WakeUpPro(LVItems[i, 2]);
        Inc(n);
        i := LVNextSelected(i);
        if iEdit3.Text <> '' then
          sleep(StrToInt(iEdit3.Text))
        else
          sleep(1);
      end;
    end;
  MakeEnd(TITLE_WAKEUP, n);
end;

procedure SaveList(Sender: PObj);
var
  i                 : Integer;
  f                 : textfile;
begin
  WritePrivateProfileString('set', 'startip', PChar(iEdit1.Text), PChar(cfgfile));
  WritePrivateProfileString('set', 'endip', PChar(iEdit2.Text), PChar(cfgfile));

  if ((ListView.Count > 0) and isChange) or Assigned(Sender) then
  begin
    if not Assigned(Sender) then
      if Messagebox(W.Handle, '�Ƿ񱣴��б�?', 'HOU��ʾ', MB_YESNO + MB_ICONQUESTION) = IDNO then
        Exit;

    if FileExists(Conf) then
      if Messagebox(W.Handle, 'IpMac�б��Ѵ��ڣ��Ƿ񸲸ǣ�',
        'HOU��ʾ', MB_YESNO + MB_ICONQUESTION) = IDNO then
        Exit;

    assignfile(f, Conf);
    rewrite(f);
    with ListView^ do
      for i := 0 to Count - 1 do
        writeln(f, LVItems[i, 0] + #9 + LVItems[i, 1] + #9 + LVItems[i, 2]);
    closefile(f);                       //�ر��ļ�
  end;
  isChange := False;
end;

procedure LoadList(Sender: PObj);
var
  f                 : textfile;
  s                 : string;
  szBuf             : array[0..255] of char;
  dwSize            : DWORD;
begin                                   //����
  if not Assigned(Sender) then
  begin
    GetPrivateProfileString('set', 'startip', '192.168.0.1', szBuf, dwSize, PChar(cfgfile));
    iEdit1.Text := szBuf;
    GetPrivateProfileString('set', 'endip', '192.168.0.254', szBuf, dwSize, PChar(cfgfile));
    iEdit2.Text := szBuf;
  end else
    if fileexists(Conf) then begin
      StartTickCount := GetTickCount;
      assignfile(f, Conf);
      reset(f); with ListView^ do begin
        Clear;
        while not eof(f) do begin
          readln(f, s);
          LVItemAdd(GetSubStrEx(s, '', #9, s));
          LVItems[Count - 1, 1] := GetSubStrEx(s, '', #9, s);
          LVItems[Count - 1, 2] := GetSubStrEx(s, '', '', s);
          LVItems[Count - 1, 3] := '0';
          LVItems[Count - 1, 4] := MAC_NO;
          LVItems[Count - 1, 5] := STATUS_DOWN;
        end;
        closefile(f);                   //�ر��ļ�
        MakeEnd(TITLE_LOAD, 0);
      end;
      isChange := False;
    end;
end;

procedure ShowHelp;
begin
  Messagebox(W.Handle, pchar(StrDec('BBDE5D804CCE3EFD43B40286514DA47582399378A740B57EBB04A058996452B060BA09EFDB19F03788268502E41AAA1EC050D07BDD08F04AB800A75F') + '	����ARP����ԭ�����߳�ɨ�裬��ɨ������IP�豸!'#13#10#13#10'����IP�����߻����϶��뽫�߳������ӣ������٣�'#13#10#13#10'Ĭ���߳���Ϊ0,ʵ�ʹ����߳�������IP��(��������1000).'), '����', 0);
end;

procedure OnListVPopup(Sender: PObj);
var
  CursorPos         : TPoint;
begin
  if ListView.RightClick then
    if GetCursorPos(CursorPos) then
      PopupMenu.PopupEx(CursorPos.X, CursorPos.Y);
end;

procedure OnStratBtn(Sender: PObj);
begin
  if StartBtn.caption = BTN_START then begin
    W.caption := '��ʼ��...';
    TF_stop := false;
    StartScan;
  end
  else
    TF_stop := true;
end;

procedure OnClearBtn(Sender: PObj);
begin
  ListView.Clear;
end;

function OnFormMessage(dummy: Pointer; var Msg: TMsg; var Rslt: Integer): boolean;
begin
  result := false;
  case Msg.Message of
    WM_CLOSE: begin
        TF_stop := true;
        SaveList(nil);
      end;
    WM_HELP: ShowHelp;
  end;
end;

procedure OnPopupMenu(dummy: Pointer; Sender: PMenu; Item: Integer);
var
  i                 : Integer;
begin
  case Item of
    0: ShowHelp;
    2: if TF_stop and (ListView.LVSelCount > 0) then
        BeginThread(nil, 0, @StartWakeUp, nil, 0, ThID);
    4: SaveList(Sender);
    6: LoadList(Sender);
    8: with ListView^ do
        if LVSelCount > 0 then
          repeat
            i := LVCurItem;
            LVDelete(i);
          until i < 0;
    10: W.Close;
  end;
end;

procedure ScanSetControl;
begin
  gSet := NewGroupBox(W, 'IP��Χ �� ɨ���̡߳�OR��������ʱ').SetSize(100, 50);
  gSet.Align := caTop;

  Label1 := NewLabel(gSet, '++>').SetPosition(105, 22);
  with Label1^ do begin
    Width := 20;
    Font.Color := clBlue;
  end;

  iEdit1 := NewEditBox(gSet, []).SetPosition(8, 20);
  with iEdit1^ do begin
    Width := 95;
    Color := clWhite;
    //Text := '192.168.0.1';
  end;

  iEdit2 := NewEditBox(gSet, []).SetPosition(125, 20);
  with iEdit2^ do begin
    Width := 95;
    Color := clWhite;
    //Text := '192.168.0.254';
  end;

  iEdit3 := NewEditBox(gSet, []).SetPosition(228, 20);
  with iEdit3^ do begin
    Width := 30;
    TextAlign := taCenter;
    Color := clWhite;
    Text := '0';
  end;

  StartBtn := NewButton(gSet, BTN_START).SetPosition(266, 20); ;
  with StartBtn^ do begin
    OnClick := TOnEvent(MakeMethod(nil, @OnStratBtn));
  end;

  ClearBtn := NewButton(gSet, '���(&C)').SetPosition(336, 20); ;
  with ClearBtn^ do begin
    OnClick := TOnEvent(MakeMethod(nil, @OnClearBtn));
  end;
end;

procedure ScanListControl;
begin
  gScanList := NewGroupBox(W, '�б�' + StrDec('9F249768AEBA73926D3310A42EC557858F349778BE40A96A8F34978364BF377DFA7DDE25A942AB10C57E840CE134FE69FC6CDE75AE50B96A9F'));
  gScanList.Align := caClient;

  ListView := NewListView(gScanList, lvsDetail, [lvoGridLines, lvoRowSelect, lvoMultiselect, lvoHeaderDragDrop, lvoSortAscending], nil, nil, nil);
  with ListView^ do begin
    OnClick := TOnEvent(MakeMethod(nil, @OnListVPopup));
    Align := caClient;
    LVColAdd('����', taCenter, 50);
    LVColAdd('IP��ַ', taLeft, 95);
    LVColAdd('MAC��ַ', taLeft, 115);
    LVColAdd('�߳�', taCenter, 50);
    LVColAdd('���', taCenter, 45);
    LVColAdd('״̬', taCenter, 45);
  end;
end;

procedure CreateControls;
begin
  ScanSetControl;
  ScanListControl;
  PopupMenu := newMenu(ListView, 100, [], TOnMenuItem(MakeMethod(nil, @OnPopupMenu)));
  with PopupMenu^ do begin
    Insert(-1, '����', nil, []);
    Insert(-1, '-', nil, [moSeparator]);
    Insert(-1, '����', nil, []);
    Insert(-1, '-', nil, [moSeparator]);
    Insert(-1, '����', nil, []);
    Insert(-1, '-', nil, [moSeparator]);
    Insert(-1, '����', nil, []);
    Insert(-1, '-', nil, [moSeparator]);
    Insert(-1, 'ɾ��', nil, []);
    Insert(-1, '-', nil, [moSeparator]);
    Insert(-1, '�˳�', nil, []);
  end;
end;

procedure ApplicationRun;
begin
  Applet := newApplet('IP-MAC');
  Applet.ExStyle := 0;
  AppButtonUsed := true;
  W := newForm(Applet, 'IP-MACɨ��-���绽�� v1.2a').SetSize(450, 380);
  with W^ do begin
    Style := WS_OVERLAPPED + WS_CAPTION + WS_SYSMENU + WS_MINIMIZEBOX + WS_MAXIMIZEBOX + WS_THICKFRAME;
    CenterOnParent;
    OnMessage := TOnMessage(MakeMethod(nil, @OnFormMessage));
    Font.FontHeight := -12;
  end;
  CreateControls;

  LoadList(nil);
  SetProcessWorkingSetSize(GetCurrentProcess, $FFFFFFFF, $FFFFFFFF);
  Run(Applet);                          //��Ϣѭ��
  Applet.Free;
end;

initialization
  cfgfile := ExtractFilePath(ParamStr(0)) + 'IPMac.ini';

end.

