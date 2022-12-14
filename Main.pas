unit Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Maps,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.MultiView, FMX.ListBox,
  FMX.Layouts, System.Sensors, System.Sensors.Components, System.Permissions, System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient, System.Threading, Json,
  System.ImageList, FMX.ImgList
  {$IFDEF ANDROID}
  , FMX.Platform.Android, Androidapi.JNI.Widget, FMX.Helpers.Android, AndroidApi.Helpers,
  Androidapi.JNI.Os
  {$ENDIF};

// ????????? ??? ???????? ?????????? ? ??????????
type TransportOptions = record
  imei: Int64;
  gov_number: string;
  route_id: string;
  route_short_name: string;
  route_long_name: string;
  route_type: string;
  time: string;
  longitude: Double;
  latitude: Double;
  satellites: Integer;
  speed: Integer;
end;

type
  TMyForm = class(TForm)
    ImageList1: TImageList;
    MyLocationSensor: TLocationSensor;
    MyMap: TMapView;
    MyMultiView: TMultiView;
    ScrollBox1: TScrollBox;
    Label2: TLabel;
    ListBox1: TListBox;
    ListBoxGroupHeader1: TListBoxGroupHeader;
    ListBoxItem1: TListBoxItem;
    TrackBarRotate: TTrackBar;
    ListBoxGroupHeader2: TListBoxGroupHeader;
    ListBoxItem2: TListBoxItem;
    TrackBarTilt: TTrackBar;
    ListBoxGroupHeader3: TListBoxGroupHeader;
    ListBoxItem3: TListBoxItem;
    ListBoxItem4: TListBoxItem;
    ListBoxItem5: TListBoxItem;
    ListBoxGroupHeader4: TListBoxGroupHeader;
    ListBoxItem6: TListBoxItem;
    LocationSwitch: TSwitch;
    ProgressBar1: TProgressBar;
    ToolBar1: TToolBar;
    DrawerBtn: TButton;
    Label1: TLabel;
    Button1: TButton;
    ToolBar2: TToolBar;
    ButtonAddMarker: TButton;
    ButtonDeleteMarker: TButton;
    ButtonDrawLine: TButton;
    DeleteLineBtn: TButton;
    procedure ButtonAddMarkerClick(Sender: TObject);
    procedure ButtonDeleteMarkerClick(Sender: TObject);
    procedure ButtonDrawLineClick(Sender: TObject);
    procedure DeleteLineBtnClick(Sender: TObject);
    procedure LocationSwitchSwitch(Sender: TObject);
    procedure ListBoxItem3Click(Sender: TObject);
    procedure ListBoxItem4Click(Sender: TObject);
    procedure ListBoxItem5Click(Sender: TObject);
    procedure MyLocationSensorLocationChanged(Sender: TObject;
      const OldLocation, NewLocation: TLocationCoord2D);
    procedure Button1Click(Sender: TObject);
    procedure MyMultiViewStartHiding(Sender: TObject);
    procedure MyMultiViewStartShowing(Sender: TObject);
    procedure MyMapMarkerClick(Marker: TMapMarker);
    procedure MyMapMarkerDoubleClick(Marker: TMapMarker);
    procedure TrackBarRotateChange(Sender: TObject);
    procedure TrackBarTiltChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
  private
    { Private declarations }
  public
    { Public declarations }
     { Public declarations }
    // ?????? ??????????????
    MyLocationMarker:TMapMarker;
    // ?????? ????????????
    MyMarker:TMapMarker;
    // ?????????? ???????? ?????????????? ? ????????????
    MyLocationPoint:TPointF;
    MyMarkerPoint:TPointF;
    // ???????? ?????
    MyLineDescriptor:TMapPolylineDescriptor;
    // ?????
    MyLine:TMapPolyline;
    // ????? ????????? ?????
    Points:TArray<TMapCoordinate>;
    transportinfo:string;
    // ?????? ?????????? ? ??????????
    TransportArr:TArray<TransportOptions>;
    // ?????? ???????? ??????????
    DevicesMarkerArr:TArray<TMapMarker>;
    FPermissionAccessFineLocation: string;
    FPermissionAccessCoarseLocation: string;
  end;

const MapType: array [1..3] of TMapType =(TMapType.Normal, TMapType.Satellite, TMapType.Hybrid);

var
  MyForm: TMyForm;

implementation

{$R *.fmx}

procedure IconIdentification(var rt:string; var ImageList:TImageList; var MapDescriptor:TMapMarkerDescriptor);
var j:integer; const route_short: array [1..15] of string =('6', '7-?','5','33','16?','5A','32','11','23','2','8','7','1','7A','31');
begin
  for j:=1 to 15 do
  begin
    if rt=route_short[j] then
    begin
      MapDescriptor.Icon:=ImageList.Source[0].Source.Items[0].MultiResBitmap[j-1].Bitmap;
      Break;
    end
  end;
end;


// ??????? ??? ???????? ??????? ?? ?????? ? ????????? ?????? ?? ????????? http
function idHttpGet(const aURL: string): string;
// uses  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient;
var
  Resp: TStringStream;
  Return: IHTTPResponse;
begin
  Result := '';
  with TNetHTTPClient.Create(nil) do
  begin
    Resp := TStringStream.Create('', TEncoding.UTF8);
    Return := Get( { TURI.URLEncode } (aURL), Resp);
    Result := Resp.DataString;
    Resp.Free;
    Free;
  end;
end;

// ????????????? ?????? ?? ??????????

procedure ExitConfirm;
begin

// ????? ??????????? ????

    MessageDlg('?????? ?????!', System.UITypes.TMsgDlgType.mtInformation,
    [
      System.UITypes.TMsgDlgBtn.mbYes,
      System.UITypes.TMsgDlgBtn.mbNo
    ], 0,
      procedure(const AResult: TModalResult)
      begin
        case AResult
          of
          mrYES:
          begin
            {$IFDEF ANDROID}
              MainActivity.finish;    // ????? ?? ??????????
            {$ENDIF}
            {$IFDEF MSWINDOWS}
              Application.Terminate;
            {$ENDIF}

          end;
          mrNo:
            begin

            end;
        end;
      end
    )

end;


// ????????? ???????????????? ?????? ?? ?????
procedure TMyForm.Button1Click(Sender: TObject);
var responsejson:string;
    JSON:TJSONObject; JSONMyArr:TJSONArray;
    MarkerLocation: TMapCoordinate; // ?????????? ???????
    MyMarkerDescr: TMapMarkerDescriptor; // ???????? ???????? ???? ???????
begin
// ????????? ? ?????? ?????? ?? ?????? ? ????????? ????????
TTask.Run(procedure
var i:integer;
begin
    // ??????????? ????????

    // ???????? ?????????? ? ?????????????? ?????????? ? ??????? json
    responsejson:=UTF8Encode(idHttpGet(transportinfo));

    responsejson:='{"mainarr":'+responsejson+'}';

    JSON := TJSONObject.ParseJSONValue(responsejson) as TJSONObject;
    JSONMyArr:=TJSONArray(JSON.Get('mainarr').JsonValue);
    FormatSettings.DecimalSeparator:='.';

    // ????????????? ?????? ????????????? ???????
    SetLength(TransportArr,JSONMyArr.Size);

    TThread.Synchronize(nil,procedure
    begin
      ProgressBar1.Max:=JSONMyArr.Size;
      Exit;
    end);

    // ????????????? ?????? ???????
    SetLength(DevicesMarkerArr,JSONMyArr.Size);

    // ??????? ??? ??????? ? ??????????? ?? "???????"
    for i:=0 to JSONMyArr.Size-1 do
    begin
    // ?????????, ???? ?? ?????? ?? ?????
        if DevicesMarkerArr[i]<>nil then
        begin
         TThread.Synchronize(nil, procedure
         begin
            DevicesMarkerArr[i].Remove;  // ??????? ??????
            Exit;
         end);
          DevicesMarkerArr[i]:=nil;    // ??????????? ??????? "???????"
        end;
    end;

    // ???????? ?????????? ? ??????????
    for i:=0 to JSONMyArr.Size-1 do
    begin
      TransportArr[i].imei:=Int64.Parse(TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('imei')).JsonValue.Value);
      TransportArr[i].gov_number:=TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('gov_number')).JsonValue.Value;
      TransportArr[i].route_id:=TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('route_id')).JsonValue.Value;
      TransportArr[i].route_short_name:=TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('route_short_name')).JsonValue.Value;
      TransportArr[i].route_long_name:=TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('route_long_name')).JsonValue.Value;
      TransportArr[i].route_type:=TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('route_type')).JsonValue.Value;
      TransportArr[i].time:=TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('time')).JsonValue.Value;
      TransportArr[i].longitude:=Double.Parse(TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('longitude')).JsonValue.Value);
      TransportArr[i].latitude:=Double.Parse(TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('latitude')).JsonValue.Value);
      TransportArr[i].satellites:=Integer.Parse(TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('satellites')).JsonValue.Value);
      TransportArr[i].speed:=Integer.Parse(TJSONPair(TJSONObject(JSONMyArr.Get(i)).Get('speed')).JsonValue.Value);
      TThread.Synchronize(nil, procedure
      begin
        ProgressBar1.Value:=i+1;
        Sleep(10);
        Exit;
      end);
    end;

    //
    SetLength(DevicesMarkerArr,JSONMyArr.Size);

    // ??????? ??? ??????? ?? ?????
    for i:=0 to JSONMyArr.Size-1 do
    begin
    // ?????????, ???? ?? ??? ?????? ?? ????? (????????? ?? "???????")
    if DevicesMarkerArr[i]=nil then
      begin

          MarkerLocation.Latitude:=TransportArr[i].latitude;
          MarkerLocation.Longitude:=TransportArr[i].longitude;

          MyMarkerDescr := TMapMarkerDescriptor.Create(MarkerLocation, TransportArr[i].route_long_name);  // ??????? ???????? ???????

          TThread.Synchronize(nil, procedure
          begin
            IconIdentification(TransportArr[i].route_short_name,ImageList1,MyMarkerDescr);
          end);

          MyMarkerDescr.Snippet:='????????: '+TransportArr[i].speed.ToString+' ??/?'+#13#10
          +'?????: '+TransportArr[i].time+#13#10+'?????: '+TransportArr[i].gov_number+#13#10+
          '???????: '+TransportArr[i].route_short_name+#13#10+'??? ????????: '+TransportArr[i].route_type+
          #13#10+'imei: '+TransportArr[i].imei.ToString;
          MyMarkerDescr.Draggable := False;

          TThread.Synchronize(nil, procedure
          begin
            DevicesMarkerArr[i] := MyMap.AddMarker(MyMarkerDescr); // ??????????? ??????? ???????? ? ????????? ?? ?????
          end);

      end;
    end;
  //-------------------------------------------------------//
end);
end;


procedure TMyForm.ButtonAddMarkerClick(Sender: TObject);
var MarkerLocation: TMapCoordinate; // ?????????? ???????
    MyMarkerDescr: TMapMarkerDescriptor; // ???????? ???????? ???? ???????
begin
// ?????????, ???? ?? ??? ?????? ?? ????? (????????? ?? "???????")
  if MyMarker=nil then
  begin
	  MarkerLocation := TMapCoordinate.Create(MyMarkerPoint);  // ????????? ?????????? ?? TPointF ? TMapCoordinate
    MyMarkerDescr := TMapMarkerDescriptor.Create(MarkerLocation, '??? ??? ??????)');  // ??????? ???????? ???????
    MyMarkerDescr.Draggable := True;  // ?????? ????? ?????????? ?? ?????
    MyMarker := MyMap.AddMarker(MyMarkerDescr); // ??????????? ??????? ???????? ? ????????? ?? ?????
  end;
end;

// ??????? ??????
procedure TMyForm.ButtonDeleteMarkerClick(Sender: TObject);
begin
// ?????????, ???? ?? ?????? ?? ?????
      if MyMarker<>nil then
      begin
        MyMarker.Remove;  // ??????? ??????
        MyMarker:=nil;    // ??????????? ??????? "???????"
      end;
end;

// ?????? ?????
procedure TMyForm.ButtonDrawLineClick(Sender: TObject);
begin
// ?????????, ???? ?? ??? ????? ?? ?????
  if MyLine=nil then
  begin
    // ????????????? ?????? ????????????? ??????? (??? ?????????? ????? ????? ??? ?????)
    SetLength(Points,2);
    //  ????? ????? ????????? ?????? ?????????????? ? ???????????????? ??????
    //  ??????? ????? ?? ?????? ????????? ?????????????? ????????
    Points[0] := TMapCoordinate.Create(MyLocationPoint);
    Points[1] := TMapCoordinate.Create(MyMarkerPoint);
    // ??????? ???????? ????? ?? ?????? ?????
    MyLineDescriptor := TMapPolylineDescriptor.Create(Points);
    // ????????????? ??????? ?????
    MyLineDescriptor.StrokeWidth := 20;
    // ????????????? ???? ?????
    MyLineDescriptor.StrokeColor := TAlphaColors.YellowGreen;
    // ????????? ????? ?? ?????
    MyLine := MyMap.AddPolyline(MyLineDescriptor);
  end
  else
  begin
  // ???? ????? ??? ????????? - ???????
    Myline.Remove;
    Myline := nil;
  end;
end;

// ???????? ?????
procedure TMyForm.DeleteLineBtnClick(Sender: TObject);
begin
// ???? ????? ???? ?? ????? - ???????
  if MyLine<>nil then
  begin
    Myline.Remove;
    Myline := nil;
  end;
end;


//*********************************************************//
// ??? ???????????? ????? ?????????? ??? ???????????? LocationSensor
procedure TMyForm.LocationSwitchSwitch(Sender: TObject);
begin
	if LocationSwitch.IsChecked then
  begin
		MyLocationSensor.Active:=true;
    {$IFDEF ANDROID}
			TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('Location Sensor On'), TJToast.JavaClass.LENGTH_LONG).show;
		{$ENDIF}
  end
	else
	begin
		MyLocationSensor.Active:=false;
    {$IFDEF ANDROID}
			TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('Location Sensor Off'), TJToast.JavaClass.LENGTH_LONG).show;
		{$ENDIF}
	end;
end;

// ?????????? ??????? ????????? ??????????????
procedure TMyForm.MyLocationSensorLocationChanged(Sender: TObject;
  const OldLocation, NewLocation: TLocationCoord2D);
var MyMarkerLocationDescr: TMapMarkerDescriptor; MyLocation: TMapCoordinate;
begin
      // ?????????????? ?????
	      MyMap.Repaint;
      // ??????????? ?????????? ?????? ??????????????
	      MyLocationPoint.X := NewLocation.Latitude;
        MyLocationPoint.Y := NewLocation.Longitude;

   // ?????????, ???? ?? ?? ????? ?????? ???????? ??????????????
    if MyLocationMarker=nil then
    begin
    // ?????????? ?????????????? (??????????? ??????????? GPS ??????? ??? Wi-Fi ?????)
	      MyLocation := TMapCoordinate.Create(MyLocationPoint);
    // ?????????? ????? ???????? ??????????? ??????????????
        MyMap.Location := MyLocation;
    // ??????? ???????? ???????
        MyMarkerLocationDescr := TMapMarkerDescriptor.Create(MyLocation,'? ?????!)));');
    // ??????????? ??????? ??? ???????
          with MyMarkerLocationDescr do
          begin
            Draggable := False;  // ?????? ?? ??????????? ?? ?????
            Visible := True;     // ????????? ???????
            Appearance := TMarkerAppearance.Billboard; // ??????? ??? - ???????? ??????
            Snippet := Format('Lat/Lon: %s,%s',[FloatToStrF(MyLocationPoint.X,ffGeneral,4,2),FloatToStrF(MyLocationPoint.Y,ffGeneral,4,2)]); // ???????? ??? ?????????
          end;

        MyLocationMarker := MyMap.AddMarker(MyMarkerLocationDescr);  // ????????? ?????? ?? ?????
        MyMap.Zoom:=30; // ??? ????? 30
    end
    else
    // ???? ?????? ??? ?????????? ?? ????? - ???????
    begin
        MyLocationMarker.Remove;
        MyLocationMarker := nil;
    end;
end;


// ????????????? ??? ?????                                  //
procedure TMyForm.ListBoxItem3Click(Sender: TObject);
begin
  //MyMap.MapType := TMapType.Normal;
 MyMap.MapType := MapType[1];
end;

procedure TMyForm.ListBoxItem4Click(Sender: TObject);
begin
 // MyMap.MapType := TMapType.Satellite;
  MyMap.MapType := MapType[2];
end;

procedure TMyForm.ListBoxItem5Click(Sender: TObject);
begin
 // MyMap.MapType := TMapType.Hybrid;
  MyMap.MapType := MapType[3];
end;


// ?????????? ?????? ?? ????????
procedure TMyForm.MyMapMarkerClick(Marker: TMapMarker);
var MarkerTitle:string;
begin
// ??????????? ????????
	  MarkerTitle:=Marker.Descriptor.Title;
    // ? ??????????? ?? ???????? ??????? "????"
{$IFDEF ANDROID}
	if MarkerTitle<>'? ?????!)));' then
    TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('??????????: '+Marker.Descriptor.Position.Latitude.ToString+' '+Marker.Descriptor.Position.Longitude.ToString), TJToast.JavaClass.LENGTH_LONG).show
  else
    TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('??? ??????!)))'), TJToast.JavaClass.LENGTH_LONG).show;
{$ENDIF}
end;


procedure TMyForm.MyMapMarkerDoubleClick(Marker: TMapMarker);
var MarkerTitle:string;
begin
// ??????????? ??????????
	  MarkerTitle:=Marker.Descriptor.Snippet;
    // ? ??????????? ?? ??????????? ??????? "????"
{$IFDEF ANDROID}
    TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence(MarkerTitle), TJToast.JavaClass.LENGTH_LONG).show;
{$ENDIF}
end;

// ??? ??????? MultiView ?????????? ?????
procedure TMyForm.MyMultiViewStartHiding(Sender: TObject);
begin
  if not MyMap.Visible then MyMap.Visible:=true;
end;

// ??? ????????? MultiView ???????? ?????
procedure TMyForm.MyMultiViewStartShowing(Sender: TObject);
begin
  if MyMap.Visible then MyMap.Visible:=not MyMap.Visible;
end;

// ??????? ?????
procedure TMyForm.TrackBarRotateChange(Sender: TObject);
begin
  MyMap.Bearing := TrackBarRotate.Value;
end;

// ?????? ?????
procedure TMyForm.TrackBarTiltChange(Sender: TObject);
begin
  MyMap.Tilt := TrackBarTilt.Value;
end;

procedure TMyForm.FormCreate(Sender: TObject);
begin
{$IFDEF ANDROID}
    FPermissionAccessFineLocation:=JStringToString(TJManifest_permission.JavaClass.ACCESS_FINE_LOCATION);
    FPermissionAccessCoarseLocation:=JStringToString(TJManifest_permission.JavaClass.ACCESS_COARSE_LOCATION);
    PermissionsService.RequestPermissions([FPermissionAccessFineLocation,FPermissionAccessCoarseLocation],
  procedure(const APermissions: TArray<string>; const AGrantResults: TArray<TPermissionStatus>)
  var i:integer;
  begin
       for i:=0 to Length(AGrantResults) do
       begin
          if AGrantResults[i] = TPermissionStatus.Granted then
          begin
            case i of
            0:
              begin
              	TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('?????? ??????????? ?????????!'), TJToast.JavaClass.LENGTH_LONG).show;
              end;
            1:
              	TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('??????????????? ??????????? ?????????!'), TJToast.JavaClass.LENGTH_LONG).show;
            end;
          end
          Else
          begin
            case i of
            0:
                TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('?????? ??????????? ?????????!'), TJToast.JavaClass.LENGTH_LONG).show;
            1:
                TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('??????????????? ??????????? ?????????!'), TJToast.JavaClass.LENGTH_LONG).show;
            end;
          end;
       end;
  end);
{$ENDIF}
// ?????????? ????????????????? ??????? (?????? ? ???????)
  MyMarkerPoint.X:=41.2;
  MyMarkerPoint.Y:=40.5;
  transportinfo:='https://city.dozor.tech/ua/kramatorsk/devices';
end;

// ??? ??????? ?????? ????? ??????????? ?????? ?????? ?? ??????????
procedure TMyForm.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key = vkHardwareBack then ExitConfirm;
end;

// ??? ?????????? ?????? ?? ??????
procedure TMyForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key = vkHardwareBack then Key := 0;
end;

end.
