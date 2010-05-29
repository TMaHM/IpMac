unit FuncLib;

interface

uses
  Windows, MySysutils, Messages;

procedure OutDebug(s: string);          //�������

function StrDec(const Str: string): string; //�ַ����ܺ���

function GetSubStr(const _Str, _Start, _End: string): string;
function GetSubStrEx(const _Str, _Start, _End: string; var _LastStr: string {���²���}): string;
function GetTickCountUSec(): DWORD;     //΢���ʱ����1/1000 000��
function DiffTickCount(tOld, tNew: DWORD): DWORD; //����ʱ���
implementation

procedure OutDebug(s: string);
begin
  OutputDebugString(PChar(s));
end;

function StrDec(const Str: string): string; //�ַ����ܺ���
const
  XorKey            : array[0..7] of Byte = ($B2, $09, $AA, $55, $93, $6D, $84, $47); //�ַ���������
var
  i, j              : Integer;
begin
  Result := '';
  j := 0;
  try
    for i := 1 to Length(Str) div 2 do begin
      Result := Result + Char(StrToInt('$' + Copy(Str, i * 2 - 1, 2)) xor XorKey[j]);
      j := (j + 1) mod 8;
    end;
  except
  end;
end;

function GetSubStr(const _Str, _Start, _End: string): string;
//20100306
var
  Index             : Integer;
begin
  if _Start <> '' then
  begin
    Index := Pos(_Start, _Str);
    if Index = 0 then
    begin
      Result := '';
      Exit;
    end;
  end else
    Index := 1;

  Result := Copy(_Str, Index + Length(_Start), MaxInt);
  if _End = '' then
    Index := Length(Result) + 1
  else
    Index := Pos(_End, Result);

  Result := Copy(Result, 1, Index - 1);
end;

function GetSubStrEx(const _Str, _Start, _End: string; var _LastStr: string {���²���}): string;
//20100306 Pos �� StrPos �� 1.5��
var
  Index             : Integer;
begin
  if _Start <> '' then
  begin
    Index := Pos(_Start, _Str);
    if Index = 0 then
    begin
      Result := '';
      _LastStr := _Str;
      Exit;
    end;
  end else
    Index := 1;

  _LastStr := Copy(_Str, Index + Length(_Start), MaxInt);
  if _End = '' then
    Index := Length(_Str) + 1
  else
    Index := Pos(_End, _LastStr);

  Result := Copy(_LastStr, 1, Index - 1);
  _LastStr := Copy(_LastStr, Index + Length(_End), MaxInt);
end;

var
  Frequency         : Int64;

function GetTickCountUSec;              //�� GetTickCount���ȸ�25~30����
var
  lpPerformanceCount: Int64;
begin
  if Frequency = 0 then begin
    QueryPerformanceFrequency(Frequency); //WINDOWS API ���ؼ���Ƶ��(Intel86:1193180)(���ϵͳ�ĸ�����Ƶ�ʼ�������һ���ڵ��𶯴���)
    Frequency := Frequency div 1000000; //һ΢�����񶯴���
  end;
  QueryPerformanceCounter(lpPerformanceCount);
  Result := lpPerformanceCount div Frequency;
end;

function DiffTickCount;                 //����ʱ���
begin
  if tNew >= tOld then Result := tNew - tOld
  else Result := DWORD($FFFFFFFF) - tOld + tNew;
end;
end.

