program MyDozorApp;

uses
  System.StartUpCopy,
  FMX.Forms,
  Main in 'Main.pas' {MyForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMyForm, MyForm);
  Application.Run;
end.
