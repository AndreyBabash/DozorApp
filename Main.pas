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

// Структура для хранения информации о транспорте
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
    // Маркер местоположения
    MyLocationMarker:TMapMarker;
    // Маркер пользователя
    MyMarker:TMapMarker;
    // Координаты маркеров местоположения и пользователя
    MyLocationPoint:TPointF;
    MyMarkerPoint:TPointF;
    // Описание линии
    MyLineDescriptor:TMapPolylineDescriptor;
    // Линия
    MyLine:TMapPolyline;
    // Точки координат линии
    Points:TArray<TMapCoordinate>;
    transportinfo:string;
    // Массив информации о транспорте
    TransportArr:TArray<TransportOptions>;
    // Массив маркеров транспорта
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
var j:integer; const route_short: array [1..15] of string =('6', '7-а','5','33','16а','5A','32','11','23','2','8','7','1','7A','31');
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


// Функция для отправки запроса на сервер и получения ответа по протоколу http
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

// Подтверждение выхода из приложения

procedure ExitConfirm;
begin

// Вывод диалогового окна

    MessageDlg('Хотите выйти!', System.UITypes.TMsgDlgType.mtInformation,
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
              MainActivity.finish;    // Выход из приложения
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


// Добавляем пользовательский маркер на карту
procedure TMyForm.Button1Click(Sender: TObject);
var responsejson:string;
    JSON:TJSONObject; JSONMyArr:TJSONArray;
    MarkerLocation: TMapCoordinate; // координаты маркера
    MyMarkerDescr: TMapMarkerDescriptor; // описание внешнего вида маркера
begin
// Запускаем в потоке запрос на сервер и отрисовку маркеров
TTask.Run(procedure
var i:integer;
begin
    // Выполняемые действия

    // Получаем информацию о местоположению транспорта в формате json
    responsejson:=UTF8Encode(idHttpGet(transportinfo));

    responsejson:='{"mainarr":'+responsejson+'}';

    JSON := TJSONObject.ParseJSONValue(responsejson) as TJSONObject;
    JSONMyArr:=TJSONArray(JSON.Get('mainarr').JsonValue);
    FormatSettings.DecimalSeparator:='.';

    // Устанавливаем размер динамического массива
    SetLength(TransportArr,JSONMyArr.Size);

    TThread.Synchronize(nil,procedure
    begin
      ProgressBar1.Max:=JSONMyArr.Size;
      Exit;
    end);

    // Устанавливаем размер массива
    SetLength(DevicesMarkerArr,JSONMyArr.Size);

    // Удаляем все маркеры и присваиваем им "пустоту"
    for i:=0 to JSONMyArr.Size-1 do
    begin
    // Проверяем, есть ли маркер на карте
        if DevicesMarkerArr[i]<>nil then
        begin
         TThread.Synchronize(nil, procedure
         begin
            DevicesMarkerArr[i].Remove;  // Удаляем маркер
            Exit;
         end);
          DevicesMarkerArr[i]:=nil;    // присваиваем маркеру "пустоту"
        end;
    end;

    // Получаем информацию о транспорте
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

    // Выводим все маркеры на карту
    for i:=0 to JSONMyArr.Size-1 do
    begin
    // Проверяем, есть ли уже маркер на карте (проверяем на "пустоту")
    if DevicesMarkerArr[i]=nil then
      begin

          MarkerLocation.Latitude:=TransportArr[i].latitude;
          MarkerLocation.Longitude:=TransportArr[i].longitude;

          MyMarkerDescr := TMapMarkerDescriptor.Create(MarkerLocation, TransportArr[i].route_long_name);  // Создаем описание маркера

          TThread.Synchronize(nil, procedure
          begin
            IconIdentification(TransportArr[i].route_short_name,ImageList1,MyMarkerDescr);
          end);

          MyMarkerDescr.Snippet:='Скорость: '+TransportArr[i].speed.ToString+' км/ч'+#13#10
          +'Время: '+TransportArr[i].time+#13#10+'Номер: '+TransportArr[i].gov_number+#13#10+
          'Маршрут: '+TransportArr[i].route_short_name+#13#10+'Тип маршрута: '+TransportArr[i].route_type+
          #13#10+'imei: '+TransportArr[i].imei.ToString;
          MyMarkerDescr.Draggable := False;

          TThread.Synchronize(nil, procedure
          begin
            DevicesMarkerArr[i] := MyMap.AddMarker(MyMarkerDescr); // Присваиваем маркеру описание и добавляем на карту
          end);

      end;
    end;
  //-------------------------------------------------------//
end);
end;


procedure TMyForm.ButtonAddMarkerClick(Sender: TObject);
var MarkerLocation: TMapCoordinate; // координаты маркера
    MyMarkerDescr: TMapMarkerDescriptor; // описание внешнего вида маркера
begin
// Проверяем, есть ли уже маркер на карте (проверяем на "пустоту")
  if MyMarker=nil then
  begin
	  MarkerLocation := TMapCoordinate.Create(MyMarkerPoint);  // Переводим координаты из TPointF в TMapCoordinate
    MyMarkerDescr := TMapMarkerDescriptor.Create(MarkerLocation, 'Это мой маркер)');  // Создаем описание маркера
    MyMarkerDescr.Draggable := True;  // Маркер можно перемещать на карте
    MyMarker := MyMap.AddMarker(MyMarkerDescr); // Присваиваем маркеру описание и добавляем на карту
  end;
end;

// Удаляем маркер
procedure TMyForm.ButtonDeleteMarkerClick(Sender: TObject);
begin
// Проверяем, есть ли маркер на карте
      if MyMarker<>nil then
      begin
        MyMarker.Remove;  // Удаляем маркер
        MyMarker:=nil;    // присваиваем маркеру "пустоту"
      end;
end;

// Рисуем линию
procedure TMyForm.ButtonDrawLineClick(Sender: TObject);
begin
// Проверяем, есть ли уже линия на карте
  if MyLine=nil then
  begin
    // Устанавливаем размер динамического массива (для построения линии нужно две точки)
    SetLength(Points,2);
    //  Линия будет соединять маркер местоположения и пользовательский маркер
    //  Создаем точки на основе координат местоположения маркеров
    Points[0] := TMapCoordinate.Create(MyLocationPoint);
    Points[1] := TMapCoordinate.Create(MyMarkerPoint);
    // Создаем описание линии на основе точек
    MyLineDescriptor := TMapPolylineDescriptor.Create(Points);
    // Устанавливаем толщину линии
    MyLineDescriptor.StrokeWidth := 20;
    // Устанавливаем цвет линии
    MyLineDescriptor.StrokeColor := TAlphaColors.YellowGreen;
    // Добавляем линию на карту
    MyLine := MyMap.AddPolyline(MyLineDescriptor);
  end
  else
  begin
  // Если линия уже добавлена - удаляем
    Myline.Remove;
    Myline := nil;
  end;
end;

// Удаление линии
procedure TMyForm.DeleteLineBtnClick(Sender: TObject);
begin
// Если линия есть на карте - удаляем
  if MyLine<>nil then
  begin
    Myline.Remove;
    Myline := nil;
  end;
end;


//*********************************************************//
// При переключении свича активируем или деактивируем LocationSensor
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

// Обработчик события изменения местоположения
procedure TMyForm.MyLocationSensorLocationChanged(Sender: TObject;
  const OldLocation, NewLocation: TLocationCoord2D);
var MyMarkerLocationDescr: TMapMarkerDescriptor; MyLocation: TMapCoordinate;
begin
      // Перерисовываем карту
	      MyMap.Repaint;
      // Присваиваем координаты нового местоположения
	      MyLocationPoint.X := NewLocation.Latitude;
        MyLocationPoint.Y := NewLocation.Longitude;

   // Проверяем, есть ли на карте маркер текущего местоположения
    if MyLocationMarker=nil then
    begin
    // Координаты местоположения (вычисляется посредством GPS датчика или Wi-Fi сетей)
	      MyLocation := TMapCoordinate.Create(MyLocationPoint);
    // Перемещаем карту согласно координатам местоположения
        MyMap.Location := MyLocation;
    // Создаем описание маркера
        MyMarkerLocationDescr := TMapMarkerDescriptor.Create(MyLocation,'Я здесь!)));');
    // Настраиваем внешний вид маркера
          with MyMarkerLocationDescr do
          begin
            Draggable := False;  // запрет на перемещение по карте
            Visible := True;     // видимость маркера
            Appearance := TMarkerAppearance.Billboard; // внешний вид - обьемный маркер
            Snippet := Format('Lat/Lon: %s,%s',[FloatToStrF(MyLocationPoint.X,ffGeneral,4,2),FloatToStrF(MyLocationPoint.Y,ffGeneral,4,2)]); // описание под названием
          end;

        MyLocationMarker := MyMap.AddMarker(MyMarkerLocationDescr);  // Добавляем маркер на карту
        MyMap.Zoom:=30; // зум карты 30
    end
    else
    // Если маркер уже существует на карте - удаляем
    begin
        MyLocationMarker.Remove;
        MyLocationMarker := nil;
    end;
end;


// Устанавливаем тип карты                                  //
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


// Обработчик кликов по маркерам
procedure TMyForm.MyMapMarkerClick(Marker: TMapMarker);
var MarkerTitle:string;
begin
// запрашиваем название
	  MarkerTitle:=Marker.Descriptor.Title;
    // в зависимость от названия выводим "тост"
{$IFDEF ANDROID}
	if MarkerTitle<>'Я здесь!)));' then
    TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('Координаты: '+Marker.Descriptor.Position.Latitude.ToString+' '+Marker.Descriptor.Position.Longitude.ToString), TJToast.JavaClass.LENGTH_LONG).show
  else
    TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('Мой маркер!)))'), TJToast.JavaClass.LENGTH_LONG).show;
{$ENDIF}
end;


procedure TMyForm.MyMapMarkerDoubleClick(Marker: TMapMarker);
var MarkerTitle:string;
begin
// запрашиваем содержимое
	  MarkerTitle:=Marker.Descriptor.Snippet;
    // в зависимость от содержимого выводим "тост"
{$IFDEF ANDROID}
    TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence(MarkerTitle), TJToast.JavaClass.LENGTH_LONG).show;
{$ENDIF}
end;

// При скрытии MultiView показываем карту
procedure TMyForm.MyMultiViewStartHiding(Sender: TObject);
begin
  if not MyMap.Visible then MyMap.Visible:=true;
end;

// При появлении MultiView скрываем карту
procedure TMyForm.MyMultiViewStartShowing(Sender: TObject);
begin
  if MyMap.Visible then MyMap.Visible:=not MyMap.Visible;
end;

// Поворот карты
procedure TMyForm.TrackBarRotateChange(Sender: TObject);
begin
  MyMap.Bearing := TrackBarRotate.Value;
end;

// Наклон карты
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
              	TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('Точное определение разрешено!'), TJToast.JavaClass.LENGTH_LONG).show;
              end;
            1:
              	TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('Приблизительное определение разрешено!'), TJToast.JavaClass.LENGTH_LONG).show;
            end;
          end
          Else
          begin
            case i of
            0:
                TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('Точное определение запрещено!'), TJToast.JavaClass.LENGTH_LONG).show;
            1:
                TJToast.JavaClass.makeText(TAndroidHelper.Context, StrToJCharSequence('Приблизительное определение запрещено!'), TJToast.JavaClass.LENGTH_LONG).show;
            end;
          end;
       end;
  end);
{$ENDIF}
// Координаты пользовательского маркера (широта и долгота)
  MyMarkerPoint.X:=41.2;
  MyMarkerPoint.Y:=40.5;
  transportinfo:='https://city.dozor.tech/ua/kramatorsk/devices';
end;

// При нажатии кнопки Назад запрашиваем диалог выхода из приложения
procedure TMyForm.FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key = vkHardwareBack then ExitConfirm;
end;

// При отпускании ничего не делаем
procedure TMyForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if Key = vkHardwareBack then Key := 0;
end;

end.
