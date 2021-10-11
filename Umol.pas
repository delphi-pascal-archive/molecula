// (c) Jean Yves Quéinec  - Mai 2001
// ----------------------------------------------------------------------
// Comment intercepter les touches de direction (arrows keys) dans Delphi
// ----------------------------------------------------------------------
// Voir les lignes ayant Clavier en commentaire

unit Umol;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ColorGrd, StdCtrls, ExtCtrls, ImgList;

type
  TForm1 = class(TForm)
    Panel2: TPanel;
    ImageList1: TImageList;
    PaintBox1: TPaintBox;
    ImageList2: TImageList;
    RadioGroup1: TRadioGroup;
    ImageList3: TImageList;
    ImageList4: TImageList;
    ImageList5: TImageList;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Image1: TImage;
    Label5: TLabel;
    BtQuitter: TButton;
    CheckBox1: TCheckBox;
    Button1: TButton;
    procedure BtQuitterClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);

    procedure TraiteMessages(Var msg: TMsg; Var Handled: boolean);   //Clavier

    procedure PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PaintBox1Paint(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure RadioGroup1Click(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
  private
    Procedure Gradball(imglist : timagelist; arayon, pctspec : integer;
                          colball, collight, colmask, colspec : Tcolor);
    procedure initmolecule;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.DFM}

type
  TRGBArray = ARRAY[0..0] OF TRGBTriple;
  pRGBArray = ^TRGBArray;

Type
  Matrix  =  array[0..3, 0..3] of single;
  TDPoint =  record     { Structure pour un point en 3 Dimensions }
     X : single;
     Y : single;
     Z : single;
  end;

const
  //rayon  : integer = 100;   // rayon d'affichage
  maximum = 180;             // nombre maxi d'atomes acceptés par le programme
var
  Bmpmano  : TBitmap;                // Double buffer : bitmap de dessin
  Bmpfond  : TBitmap;                // Double Buffer : bitmao effacement
  rayon  : integer;

  // Une molécule posède pluseurs atommes et des liaisons entre atômes
  // Type atome Tat = 0  carbone      Gris foncé ou violet
  //                  1  Hydrogène    Blanc
  //                  2  Oxygène      Rouge
  //                  3  Azote        Vert
  //                  4  carbone petit bleu
  maxat : integer;                             // nombre atomes dans molécule
  tat  :  array[1..maximum] of  integer;       // Type d'atome
  Pts  :  array[1..maximum] of TDPoint;        // Position originale des atomes
  PtsR :  array[1..maximum] of TDPoint;        // atomes en rotation
  P2D : array[1..maximum] of TPoint;           // Représentation 2D des atomes
  Eloignement : array[1..maximum] of integer;  // pour choisir image de l'atome
  zTri        : array[1..maximum] of integer;  // tri selon éloignement
  Priorite    : array[1..maximum] of integer;  // priorité affichage
  XAng, YAng, ZAng : integer;                 // angles de rotation
  maxliens : integer;
  Lien : array[1..maximum] of Tpoint; // Lien.x = n° atome départ, .y n° arrivée

  // affichage
  cx, cy  : integer;                  // centre
  oldrect : Trect;                    // ancien rectangle affichage
  newrect : Trect;                    // nouveau rctangle affichage
  // tables des sinus et cosinus précalculés pour optimisation
  asin : array[0..360] of single;
  acos : array[0..360] of single;
  // déplacement de la souris
  moving : integer;  //  0 pas déplacement, 1 angles x et y , 2 angle z
  prevx, prevy : integer;

  ashift : boolean;      // Clavier
  actrl  : boolean;      // Clavier



// création et intialisation des bitmaps de fond et de manoeuvre
// création des tables de sinus et cosinus (optimisation)
// création des dessins de boules(dégradé, diminution, et estompage )
procedure TForm1.FormCreate(Sender: TObject);
const
  pirad = pi /180;
var
  i : integer;
  n : single;
begin
  ashift := false;                          //Clavier
  actrl  := false;                          //Clavier
  Application.OnMessage := TraiteMessages;  //Clavier

   prevx := 0;
   prevy := 0;
   moving := 0;
   For i := 0 to 360 do
   begin
     n := i * pirad;
     asin[i] := sin(n);
     acos[i] := cos(n);
   end;
   cx := paintbox1.width  div 2;
   cy := paintbox1.height div 2;

   Bmpmano := TBitmap.Create;
   Bmpmano.Height := Paintbox1.height;
   Bmpmano.Width  := Paintbox1.width;
   Bmpmano.pixelformat := pf24bit;
   Bmpfond := TBitmap.Create;
   Bmpfond.Height := Paintbox1.height;
   Bmpfond.Width  := Paintbox1.width;
   Bmpmano.pixelformat := pf24bit;
   // on peut aussi charger une image de fond
   with Bmpfond.Canvas do
   begin
     brush.color := clWhite;
     fillrect(rect(0,0,bmpfond.width, bmpfond.height));
   end;
   for i := 0 to 15 do
   begin
   gradball(imagelist1,16-i div 2, i*6, clblack , clwhite, cllime, clsilver);
   gradball(imagelist2,12-i div 2, i*6, clsilver, clwhite, cllime, clsilver);
   gradball(imagelist3,16-i div 2, i*6, clred   , clwhite, cllime, clsilver);
   gradball(imagelist4,16-i div 2, i*6, clgreen , clwhite, cllime, clsilver);
   gradball(imagelist5,12-i div 2, i*6, clpurple, clwhite, cllime, clsilver);
   end;
   image1.canvas.brush.color := clbtnface;
   image1.canvas.fillrect(rect(0,0,image1.width, image1.height));
   Imagelist1.draw(image1.canvas, 5,  4, 8);  //  Légende
   Imagelist2.draw(image1.canvas, 5, 28, 4);
   Imagelist3.draw(image1.canvas, 5, 52, 8);
   Imagelist4.draw(image1.canvas, 5, 76, 8);
   Imagelist5.draw(image1.canvas, 32, 4, 8);
   XAng := 20;
   YAng := 30;
   ZAng := 0;
   InitMolecule;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
   Bmpfond.Free;
   Bmpmano.Free;
end;

// Intercepte les messages clavier, en particulier les touches flèchées
Procedure Tform1.TraiteMessages(Var msg : TMsg; Var Handled: boolean);
var
  clx, cly : integer;                                            //Clavier
  B : Tmousebutton;                                              //Clavier
  S : Tshiftstate;                                               //Clavier
begin                                                            //Clavier
  With msg do                                                    //Clavier
  begin                                                          //Clavier
    if message = WM_KEYUP then                                   //Clavier
    Case wparam of                                               //Clavier
      VK_SHIFT   : ashift := false;                              //Clavier
      VK_CONTROL : actrl  := false;                              //Clavier
    end;                                                         //Clavier
    If message = WM_KEYDOWN then                                 //Clavier
    begin                                                        //Clavier
      clx := 0;                                                  //Clavier
      cly := 0;                                                  //Clavier
      Case wparam of                                             //Clavier
        VK_LEFT  : clx := -1;                                    //Clavier
        VK_RIGHT : clx :=  1;                                    //Clavier
        VK_UP    : cly := -1;                                    //Clavier
        VK_DOWN  : cly :=  1;                                    //Clavier
        VK_SHIFT   : ashift := true;                             //Clavier
        VK_CONTROL : actrl  := true;                             //Clavier
      end;                                                       //Clavier
      if Form1.active and
      (actrl OR ashift) and ((clx <> 0) OR (cly <> 0)) then   //Clavier
      begin                                                      //Clavier
        if actrl then begin clx := clx*4; cly := cly*4; end;     //Clavier                                                    //Clavier
        paintbox1MouseDown(paintbox1, B, S, 0, 0);               //Clavier
        paintbox1MouseMove(paintbox1, S, clx, cly);              //Clavier
        paintbox1MouseUp(paintbox1, B, S, 0,0);                  //Clavier
        handled := true;                                         //Clavier
      end                                                        //Clavier
      else handled := false;                                     //Clavier
    end                                                          //Clavier
    else handled := false;                                       //Clavier
  end;                                                           //Clavier
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  XAng := 0;
  YAng := 0;
  ZAng := 0;
  paintbox1paint(sender);
end;

procedure TForm1.RadioGroup1Click(Sender: TObject);
begin
  initmolecule;
end;

Function qsin(a : integer): single;
begin
  while a > 360 do dec(a, 360);
  while a < 0   do inc(a, 360);
  result := asin[a];
end;

Function qcos(a : integer): single;
begin
  while a > 360 do dec(a, 360);
  while a < 0   do inc(a, 360);
  result := acos[a];
end;

// matrice de rotation selon les 3 angles en degrés
procedure matrixRotate(var m: Matrix;  degx, degy, degz : integer);
var
  sinX, cosX,
  sinY, cosY,
  sinZ, cosZ : single;  // calculé une seule fois
  i, j : integer;
begin
  sinX := qsin(degx);
  cosX := qcos(degx);
  sinY := qsin(degy);
  cosY := qcos(degy);
  sinZ := qsin(degz);
  cosZ := qcos(degz);
  for j := 0 to 3 do
    for i := 0 to 3 do
      if i = j then  M[j, i] := 0  else M[j, i] := 1;
  M[0,0] :=  cosZ *  cosY;
  M[0,1] :=  cosZ * -sinY * -sinX + sinZ * cosX;
  M[0,2] :=  cosZ * -sinY *  cosX + sinZ * sinX;
  M[1,0] := -sinZ *  cosY;
  M[1,1] := -sinZ * -sinY * -sinX + cosZ * cosX;
  M[1,2] := -sinZ * -sinY *  cosX + cosZ * sinX;
  M[2,0] :=  sinY;
  M[2,1] :=  cosY * -sinX;
  M[2,2] :=  cosY *  cosX;
end;

// Applique la rotation à un point 3D et renvoie un nouveau point 3D
procedure ApplyMatToPoint(PointIn: TDPoint; var pointOut: TDPoint; mat: Matrix);
var
  x, y, z : single;
begin
  x := (PointIn.x*mat[0,0])+(PointIn.y*mat[0,1])+(PointIn.z*mat[0,2])+mat[0,3];
  y := (PointIn.x*mat[1,0])+(PointIn.y*mat[1,1])+(PointIn.z*mat[1,2])+mat[1,3];
  z := (PointIn.x*mat[2,0])+(PointIn.y*mat[2,1])+(PointIn.z*mat[2,2])+mat[2,3];
  PointOut.x :=  x;
  PointOut.y :=  y;
  PointOut.z :=  z;
end;

// Initialisation des coordonnées des atomes. On pourrait lire un fichier
procedure Tform1.Initmolecule;
const    // liaisons entre atomes 2 nombres par lien
 M0 = 12;
 L0 : array[1..M0*2] of integer = (01, 02, 01, 03, 03, 04, 03, 05, 05,
      06, 05, 07, 07, 08, 07, 09, 09, 10, 09, 11, 11, 12, 11, 01);

 M1 = 90;
 L1 : array[1..M1*2] of integer = (
      01, 02, 01, 05, 01, 08, 02, 03, 02, 13, 03, 04, 03, 18, 04, 05, 04,
      23, 05, 28, 06, 07, 06, 10, 06, 40, 07, 08, 07, 14, 08, 09, 09, 10,
      09, 27, 10, 56, 11, 12, 11, 15, 11, 45, 12, 13, 12, 19, 13, 14, 14,
      15, 15, 36, 16, 17, 16, 20, 16, 50, 17, 18, 17, 24, 18, 19, 19, 20,
      20, 41, 21, 22, 21, 25, 21, 55, 22, 23, 22, 29, 23, 24, 24, 25, 25,
      46, 26, 27, 26, 30, 26, 60, 27, 28, 28, 29, 29, 30, 30, 51, 31, 32,
      31, 35, 31, 38, 32, 33, 32, 43, 33, 34, 33, 48, 34, 35, 34, 53, 35,
      58, 36, 37, 36, 40, 37, 38, 37, 44, 38, 39, 39, 40, 39, 57, 41, 42,
      41, 45, 42, 43, 42, 49, 43, 44, 44, 45, 46, 47, 46, 50, 47, 48, 47,
      54, 48, 49, 49, 50, 51, 52, 51, 55, 52, 53, 52, 59, 53, 54, 54, 55,
      56, 57, 56, 60, 57, 58, 58, 59, 59, 60);
 M2 = 2;
 L2 : array[1..M2*2] of integer = (1, 2, 1,3);

 M3 = 18;
 L3 : array[1..M3*2] of integer =
     (03, 06, 06, 09, 09, 12, 12, 15, 15, 18, 18, 03, 03, 01, 03, 02,
      06, 04, 06, 05, 09, 07, 09, 08, 12, 10, 12, 11, 15, 13, 15, 14,
      18, 16, 18, 17);

 M4 = 7;
 L4 : array[1..M4*2] of integer =
     (07, 08, 07, 01, 07, 03, 07, 05, 08, 02, 08, 04, 08, 06);

 M5 = 17;
 L5 : array[1..M5*2] of integer =
   (03, 02, 02, 05, 05, 06, 06, 07, 03, 04, 03, 10, 07, 08, 07, 09, 02, 01,
    06, 16, 06, 17, 05, 14, 05, 15, 02, 12, 01, 11, 01, 18, 01,13);

 M6 = 16;
 L6 : array[1..M6*2] of integer = (
      01, 02, 02, 03, 02, 07, 03, 04, 04, 09, 04, 12, 05, 02, 05, 06, 06,
      10, 06, 13, 07, 08, 08, 09, 08, 11, 10, 08, 13, 04, 14, 06);
var
  i : integer;
  raymax : single;
  k : single;
begin
  oldrect := rect(0,0,bmpmano.width, bmpmano.height); // pour effacement total
  Case radiogroup1.itemindex of

  0:begin // benzène
  maxat := 12;
  rayon := 100;
  tat[01]:=0; Pts[01].X:= 0.0998; Pts[01].Y:= 0.9950; Pts[01].Z:= 0;
  tat[02]:=1; Pts[02].X:= 0.1597; Pts[02].Y:= 1.5920; Pts[02].Z:= 0;
  tat[03]:=0; Pts[03].X:= 0.9116; Pts[03].Y:= 0.4110; Pts[03].Z:= 0;
  tat[04]:=1; Pts[04].X:= 1.4585; Pts[04].Y:= 0.6576; Pts[04].Z:= 0;
  tat[05]:=0; Pts[05].X:= 0.8117; Pts[05].Y:=-0.5839; Pts[05].Z:= 0;
  tat[06]:=1; Pts[06].X:= 1.2988; Pts[06].Y:=-0.9343; Pts[06].Z:= 0;
  tat[07]:=0; Pts[07].X:=-0.0998; Pts[07].Y:=-0.9950; Pts[07].Z:= 0;
  tat[08]:=1; Pts[08].X:=-0.1597; Pts[08].Y:=-1.5920; Pts[08].Z:= 0;
  tat[09]:=0; Pts[09].X:=-0.9116; Pts[09].Y:=-0.4110; Pts[09].Z:= 0;
  tat[10]:=1; Pts[10].X:=-1.4585; Pts[10].Y:=-0.6576; Pts[10].Z:= 0;
  tat[11]:=0; Pts[11].X:=-0.8117; Pts[11].Y:= 0.5839; Pts[11].Z:= 0;
  tat[12]:=1; Pts[12].X:=-1.2988; Pts[12].Y:= 0.9343; Pts[12].Z:= 0;
  maxliens := M0;
  for i := 1 to M0 do
  begin
   lien[i].x := L0[i*2-1];
   lien[i].y := L0[i*2];
  end;
  end;

1: begin  // Fullerène C60
  maxat := 60;
  rayon := 140;
  tat[01]:=0; Pts[01].X:= 1.2265; Pts[01].Y:= 0.0000; Pts[01].Z:= 3.3145;
  tat[02]:=0; Pts[02].X:= 0.3790; Pts[02].Y:= 1.1664; Pts[02].Z:= 3.3145;
  tat[03]:=0; Pts[03].X:=-0.9922; Pts[03].Y:= 0.7209; Pts[03].Z:= 3.3145;
  tat[04]:=0; Pts[04].X:=-0.9922; Pts[04].Y:=-0.7209; Pts[04].Z:= 3.3145;
  tat[05]:=0; Pts[05].X:= 0.3790; Pts[05].Y:=-1.1664; Pts[05].Z:= 3.3145;
  tat[06]:=0; Pts[06].X:= 3.4084; Pts[06].Y:= 0.7209; Pts[06].Z:= 0.5948;
  tat[07]:=0; Pts[07].X:= 2.7951; Pts[07].Y:= 1.1664; Pts[07].Z:= 1.8213;
  tat[08]:=0; Pts[08].X:= 2.4161; Pts[08].Y:= 0.0000; Pts[08].Z:= 2.5793;
  tat[09]:=0; Pts[09].X:= 2.7951; Pts[09].Y:=-1.1664; Pts[09].Z:= 1.8213;
  tat[10]:=0; Pts[10].X:= 3.4084; Pts[10].Y:=-0.7209; Pts[10].Z:= 0.5948;
  tat[11]:=0; Pts[11].X:= 0.3676; Pts[11].Y:= 3.4643; Pts[11].Z:= 0.5948;
  tat[12]:=0; Pts[12].X:=-0.2456; Pts[12].Y:= 3.0188; Pts[12].Z:= 1.8213;
  tat[13]:=0; Pts[13].X:= 0.7466; Pts[13].Y:= 2.2979; Pts[13].Z:= 2.5793;
  tat[14]:=0; Pts[14].X:= 1.9731; Pts[14].Y:= 2.2979; Pts[14].Z:= 1.8213;
  tat[15]:=0; Pts[15].X:= 1.7389; Pts[15].Y:= 3.0188; Pts[15].Z:= 0.5948;
  tat[16]:=0; Pts[16].X:=-3.1812; Pts[16].Y:= 1.4202; Pts[16].Z:= 0.5948;
  tat[17]:=0; Pts[17].X:=-2.9469; Pts[17].Y:= 0.6993; Pts[17].Z:= 1.8213;
  tat[18]:=0; Pts[18].X:=-1.9547; Pts[18].Y:= 1.4202; Pts[18].Z:= 2.5793;
  tat[19]:=0; Pts[19].X:=-1.5757; Pts[19].Y:= 2.5866; Pts[19].Z:= 1.8213;
  tat[20]:=0; Pts[20].X:=-2.3337; Pts[20].Y:= 2.5866; Pts[20].Z:= 0.5948;
  tat[21]:=0; Pts[21].X:=-2.3337; Pts[21].Y:=-2.5866; Pts[21].Z:= 0.5948;
  tat[22]:=0; Pts[22].X:=-1.5757; Pts[22].Y:=-2.5866; Pts[22].Z:= 1.8213;
  tat[23]:=0; Pts[23].X:=-1.9547; Pts[23].Y:=-1.4202; Pts[23].Z:= 2.5793;
  tat[24]:=0; Pts[24].X:=-2.9469; Pts[24].Y:=-0.6993; Pts[24].Z:= 1.8213;
  tat[25]:=0; Pts[25].X:=-3.1812; Pts[25].Y:=-1.4202; Pts[25].Z:= 0.5948;
  tat[26]:=0; Pts[26].X:= 1.7389; Pts[26].Y:=-3.0188; Pts[26].Z:= 0.5948;
  tat[27]:=0; Pts[27].X:= 1.9731; Pts[27].Y:=-2.2979; Pts[27].Z:= 1.8213;
  tat[28]:=0; Pts[28].X:= 0.7466; Pts[28].Y:=-2.2979; Pts[28].Z:= 2.5793;
  tat[29]:=0; Pts[29].X:=-0.2456; Pts[29].Y:=-3.0188; Pts[29].Z:= 1.8213;
  tat[30]:=0; Pts[30].X:= 0.3676; Pts[30].Y:=-3.4643; Pts[30].Z:= 0.5948;
  tat[31]:=0; Pts[31].X:= 0.9922; Pts[31].Y:= 0.7209; Pts[31].Z:=-3.3145;
  tat[32]:=0; Pts[32].X:=-0.3790; Pts[32].Y:= 1.1664; Pts[32].Z:=-3.3145;
  tat[33]:=0; Pts[33].X:=-1.2265; Pts[33].Y:= 0.0000; Pts[33].Z:=-3.3145;
  tat[34]:=0; Pts[34].X:=-0.3790; Pts[34].Y:=-1.1664; Pts[34].Z:=-3.3145;
  tat[35]:=0; Pts[35].X:= 0.9922; Pts[35].Y:=-0.7209; Pts[35].Z:=-3.3145;
  tat[36]:=0; Pts[36].X:= 2.3337; Pts[36].Y:= 2.5866; Pts[36].Z:=-0.5948;
  tat[37]:=0; Pts[37].X:= 1.5757; Pts[37].Y:= 2.5866; Pts[37].Z:=-1.8213;
  tat[38]:=0; Pts[38].X:= 1.9547; Pts[38].Y:= 1.4202; Pts[38].Z:=-2.5793;
  tat[39]:=0; Pts[39].X:= 2.9469; Pts[39].Y:= 0.6993; Pts[39].Z:=-1.8213;
  tat[40]:=0; Pts[40].X:= 3.1812; Pts[40].Y:= 1.4202; Pts[40].Z:=-0.5948;
  tat[41]:=0; Pts[41].X:=-1.7389; Pts[41].Y:= 3.0188; Pts[41].Z:=-0.5948;
  tat[42]:=0; Pts[42].X:=-1.9731; Pts[42].Y:= 2.2979; Pts[42].Z:=-1.8213;
  tat[43]:=0; Pts[43].X:=-0.7466; Pts[43].Y:= 2.2979; Pts[43].Z:=-2.5793;
  tat[44]:=0; Pts[44].X:= 0.2456; Pts[44].Y:= 3.0188; Pts[44].Z:=-1.8213;
  tat[45]:=0; Pts[45].X:=-0.3676; Pts[45].Y:= 3.4643; Pts[45].Z:=-0.5948;
  tat[46]:=0; Pts[46].X:=-3.4084; Pts[46].Y:=-0.7209; Pts[46].Z:=-0.5948;
  tat[47]:=0; Pts[47].X:=-2.7951; Pts[47].Y:=-1.1664; Pts[47].Z:=-1.8213;
  tat[48]:=0; Pts[48].X:=-2.4161; Pts[48].Y:= 0.0000; Pts[48].Z:=-2.5793;
  tat[49]:=0; Pts[49].X:=-2.7951; Pts[49].Y:= 1.1664; Pts[49].Z:=-1.8213;
  tat[50]:=0; Pts[50].X:=-3.4084; Pts[50].Y:= 0.7209; Pts[50].Z:=-0.5948;
  tat[51]:=0; Pts[51].X:=-0.3676; Pts[51].Y:=-3.4643; Pts[51].Z:=-0.5948;
  tat[52]:=0; Pts[52].X:= 0.2456; Pts[52].Y:=-3.0188; Pts[52].Z:=-1.8213;
  tat[53]:=0; Pts[53].X:=-0.7466; Pts[53].Y:=-2.2979; Pts[53].Z:=-2.5793;
  tat[54]:=0; Pts[54].X:=-1.9731; Pts[54].Y:=-2.2979; Pts[54].Z:=-1.8213;
  tat[55]:=0; Pts[55].X:=-1.7389; Pts[55].Y:=-3.0188; Pts[55].Z:=-0.5948;
  tat[56]:=0; Pts[56].X:= 3.1812; Pts[56].Y:=-1.4202; Pts[56].Z:=-0.5948;
  tat[57]:=0; Pts[57].X:= 2.9469; Pts[57].Y:=-0.6993; Pts[57].Z:=-1.8213;
  tat[58]:=0; Pts[58].X:= 1.9547; Pts[58].Y:=-1.4202; Pts[58].Z:=-2.5793;
  tat[59]:=0; Pts[59].X:= 1.5757; Pts[59].Y:=-2.5866; Pts[59].Z:=-1.8213;
  tat[60]:=0; Pts[60].X:= 2.3337; Pts[60].Y:=-2.5866; Pts[60].Z:=-0.5948;
  For i := 1 to 60 do Tat[i] := 4; // dessin petit et violet
  maxliens := M1;
  for i := 1 to M1 do
  begin
   lien[i].x := L1[i*2-1];
   lien[i].y := L1[i*2];
  end;
  end;

2:Begin     // eau (approximatif en réalité 102° au lieu de 90°)
  maxat := 3;
  Rayon := 80;
  tat[01]:= 2; Pts[01].X:= 0; Pts[01].Y:= -0.5; Pts[01].Z:= 0;
  tat[02]:= 1; Pts[02].X:=-1; Pts[02].Y:=  0.5; Pts[02].Z:= 0;
  tat[03]:= 1; Pts[03].X:= 1; Pts[03].Y:=  0.5; Pts[03].Z:= 0;
  maxliens := M2;
  for i := 1 to M2 do
  begin
    lien[i].x := L2[i*2-1];
    lien[i].y := L2[i*2];
  end;
  end;

3:Begin    // cyclohexane
  maxat := 18;
  rayon := 100;
  tat[01]:=1; Pts[01].X:= 0.0998; Pts[01].Y:= 0.9950; Pts[01].Z:=-1.20;
  tat[02]:=1; Pts[02].X:= 0.1397; Pts[02].Y:= 1.3930; Pts[02].Z:=-0.12;
  tat[03]:=0; Pts[03].X:= 0.0998; Pts[03].Y:= 0.9950; Pts[03].Z:=-0.20;
  tat[04]:=1; Pts[04].X:= 0.9116; Pts[04].Y:= 0.4110; Pts[04].Z:= 1.20;
  tat[05]:=1; Pts[05].X:= 1.2762; Pts[05].Y:= 0.5754; Pts[05].Z:= 0.12;
  tat[06]:=0; Pts[06].X:= 0.9116; Pts[06].Y:= 0.4110; Pts[06].Z:= 0.20;
  tat[07]:=1; Pts[07].X:= 0.8117; Pts[07].Y:=-0.5839; Pts[07].Z:=-1.20;
  tat[08]:=1; Pts[08].X:= 1.1365; Pts[08].Y:=-0.8175; Pts[08].Z:=-0.12;
  tat[09]:=0; Pts[09].X:= 0.8117; Pts[09].Y:=-0.5839; Pts[09].Z:=-0.20;
  tat[10]:=1; Pts[10].X:=-0.0998; Pts[10].Y:=-0.9950; Pts[10].Z:= 1.20;
  tat[11]:=1; Pts[11].X:=-0.1397; Pts[11].Y:=-1.3930; Pts[11].Z:= 0.12;
  tat[12]:=0; Pts[12].X:=-0.0998; Pts[12].Y:=-0.9950; Pts[12].Z:= 0.20;
  tat[13]:=1; Pts[13].X:=-0.9116; Pts[13].Y:=-0.4110; Pts[13].Z:=-1.20;
  tat[14]:=1; Pts[14].X:=-1.2762; Pts[14].Y:=-0.5754; Pts[14].Z:=-0.12;
  tat[15]:=0; Pts[15].X:=-0.9116; Pts[15].Y:=-0.4110; Pts[15].Z:=-0.20;
  tat[16]:=1; Pts[16].X:=-0.8117; Pts[16].Y:= 0.5839; Pts[16].Z:= 1.20;
  tat[17]:=1; Pts[17].X:=-1.1364; Pts[17].Y:= 0.8175; Pts[17].Z:= 0.12;
  tat[18]:=0; Pts[18].X:=-0.8117; Pts[18].Y:= 0.5839; Pts[18].Z:= 0.20;
  maxliens := M3;
  for i := 1 to M3 do
  begin
    lien[i].x := L3[i*2-1];
    lien[i].y := L3[i*2];
  end;
  end;

4:Begin    // éthane
  maxat := 8;
  rayon := 80;
  tat[01]:=1; Pts[01].X:= 0.0998; Pts[01].Y:= 0.9950; Pts[01].Z:=-1.1;
  tat[02]:=1; Pts[02].X:= 0.9116; Pts[02].Y:= 0.4110; Pts[02].Z:= 1.1;
  tat[03]:=1; Pts[03].X:= 0.8117; Pts[03].Y:=-0.5839; Pts[03].Z:=-1.1;
  tat[04]:=1; Pts[04].X:=-0.0998; Pts[04].Y:=-0.9950; Pts[04].Z:= 1.1;
  tat[05]:=1; Pts[05].X:=-0.9116; Pts[05].Y:=-0.4110; Pts[05].Z:=-1.1;
  tat[06]:=1; Pts[06].X:=-0.8117; Pts[06].Y:= 0.5839; Pts[06].Z:= 1.1;
  tat[07]:=0; Pts[07].X:= 0.0   ; Pts[07].Y:= 0.0   ; Pts[07].Z:=-0.5;
  tat[08]:=0; Pts[08].X:= 0.0   ; Pts[08].Y:= 0.0   ; Pts[08].Z:= 0.5;
  maxliens := M4;
  for i := 1 to M4 do
  begin
    lien[i].x := L4[i*2-1];
    lien[i].y := L4[i*2];
  end;
  end;

5:begin // acide Glutamique
  maxat := 18;
  rayon := 120;
  tat[01]:=3; Pts[01].X:= 0.7960; Pts[01].Y:= 0.7800; Pts[01].Z:= 1.7400;
  tat[02]:=0; Pts[02].X:= 1.1120; Pts[02].Y:=-0.4280; Pts[02].Z:= 0.9560;
  tat[03]:=0; Pts[03].X:= 2.6080; Pts[03].Y:=-0.4400; Pts[03].Z:= 0.6360;
  tat[04]:=2; Pts[04].X:= 3.3360; Pts[04].Y:= 0.4720; Pts[04].Z:= 1.0200;
  tat[05]:=0; Pts[05].X:= 0.2760; Pts[05].Y:=-0.5040; Pts[05].Z:=-0.3160;
  tat[06]:=0; Pts[06].X:=-1.2200; Pts[06].Y:=-0.5440; Pts[06].Z:= 0.0120;
  tat[07]:=0; Pts[07].X:=-2.0560; Pts[07].Y:=-0.6240; Pts[07].Z:=-1.2680;
  tat[08]:=2; Pts[08].X:=-1.5000; Pts[08].Y:=-0.6440; Pts[08].Z:=-2.3760;
  tat[09]:=2; Pts[09].X:=-3.3320; Pts[09].Y:=-0.6600; Pts[09].Z:=-1.0800;
  tat[10]:=2; Pts[10].X:= 3.0560; Pts[10].Y:=-1.4760; Pts[10].Z:=-0.0720;
  tat[11]:=1; Pts[11].X:= 0.0400; Pts[11].Y:= 0.5800; Pts[11].Z:= 2.3720;
  tat[12]:=1; Pts[12].X:= 0.8800; Pts[12].Y:=-1.3040; Pts[12].Z:= 1.5720;
  tat[13]:=1; Pts[13].X:= 1.6160; Pts[13].Y:= 1.0320; Pts[13].Z:= 2.2640;
  tat[14]:=1; Pts[14].X:= 0.5480; Pts[14].Y:=-1.4120; Pts[14].Z:=-0.8720;
  tat[15]:=1; Pts[15].X:= 0.4840; Pts[15].Y:= 0.3800; Pts[15].Z:=-0.9400;
  tat[16]:=1; Pts[16].X:=-1.4920; Pts[16].Y:= 0.3680; Pts[16].Z:= 0.5640;
  tat[17]:=1; Pts[17].X:=-1.4280; Pts[17].Y:=-1.4240; Pts[17].Z:= 0.6320;
  tat[18]:=1; Pts[18].X:= 0.6200; Pts[18].Y:= 1.4760; Pts[18].Z:= 1.0320;
  maxliens := M5;
  for i := 1 to M5 do
  begin
    lien[i].x := L5[i*2-1];
    lien[i].y := L5[i*2];
  end;
  end;

6:Begin // diamant
  maxat := 14;
  rayon := 80;
  tat[01]:=0; Pts[01].X:= 0.0   ; Pts[01].Y:= 0.0   ; Pts[01].Z:= 0.0;
  tat[02]:=0; Pts[02].X:= 0.9859; Pts[02].Y:= 0.9859; Pts[02].Z:= 0.9859;
  tat[03]:=0; Pts[03].X:= 0.0   ; Pts[03].Y:= 1.9719; Pts[03].Z:= 1.9719;
  tat[04]:=0; Pts[04].X:= 0.9859; Pts[04].Y:= 2.9579; Pts[04].Z:= 2.9579;
  tat[05]:=0; Pts[05].X:= 1.9719; Pts[05].Y:= 0.0   ; Pts[05].Z:= 1.9719;
  tat[06]:=0; Pts[06].X:= 2.9579; Pts[06].Y:= 0.9859; Pts[06].Z:= 2.9579;
  tat[07]:=0; Pts[07].X:= 1.9719; Pts[07].Y:= 1.9719; Pts[07].Z:= 0.0;
  tat[08]:=0; Pts[08].X:= 2.9579; Pts[08].Y:= 2.9579; Pts[08].Z:= 0.9859;
  tat[09]:=0; Pts[09].X:= 1.9719; Pts[09].Y:= 3.9438; Pts[09].Z:= 1.9719;
  tat[10]:=0; Pts[10].X:= 3.9438; Pts[10].Y:= 1.9719; Pts[10].Z:= 1.9719;
  tat[11]:=0; Pts[11].X:= 3.9438; Pts[11].Y:= 3.9438; Pts[11].Z:= 0.0;
  tat[12]:=0; Pts[12].X:= 0.0   ; Pts[12].Y:= 3.9438; Pts[12].Z:= 3.9438;
  tat[13]:=0; Pts[13].X:= 1.9719; Pts[13].Y:= 1.9719; Pts[13].Z:= 3.9438;
  tat[14]:=0; Pts[14].X:= 3.9438; Pts[14].Y:= 0.0   ; Pts[14].Z:= 3.9438;
  For i := 1 to maxat do // les coordonnées ne sont pas centrées
  begin                  // recentrage
    Pts[i].x := pts[i].x-1.9719;
    Pts[i].y := pts[i].y-1.9719;
    Pts[i].z := pts[i].z-1.9719;
  end;
  maxliens := M6;
  for i := 1 to M6 do
  begin
    lien[i].x := L6[i*2-1];
    lien[i].y := L6[i*2];
  end;
  end;

  end; // case
  // normalise
  raymax := 0.1;
  For i := 1 to maxat do
  begin
    if abs(Pts[i].x) > raymax then raymax := abs(Pts[i].x);
    if abs(Pts[i].y) > raymax then raymax := abs(Pts[i].y);
    if abs(Pts[i].z) > raymax then raymax := abs(Pts[i].z);
  end;
  k := rayon;
  k := (k*0.714) / raymax;
  For i := 1 to maxat do
  begin
    Pts[i].X := Pts[i].X*k;
    Pts[i].Y := Pts[i].Y*k;
    Pts[i].Z := Pts[i].Z*k;
  end;
  Form1.paintbox1paint(form1);
end;

procedure TForm1.BtQuitterClick(Sender: TObject);
begin
  Close;
end;


{ création d boule avec dégradé dans un TImagelist
 - Calcul de couleur lumière mélangée avec pctspec % de couleur "spéculaire".
 - Calcul de couleur boule   mélangée avec pctspec % de couleur "spéculaire".
 - Effacement du bitmap avec la couleur du masque
 - Tracé de la boule avec la couleur d'antimasque à l'aide de la fonction
    GDI ellipse qui garantit une apparence correcte du cercle.
 - Tracé du dégradé avec scanlines.
   On teste si le pixel est de la couleur de l'antimasque, donc à
   traiter, sinon on l'ignore.
      o Dans la limite du rayon rayl du dégradé on calcule la couleur
        du dégradé entre les couleurs lumière et boule.
      o En dehors de la portée du dégradé on prend la couleur de boule --}

Procedure Tform1.gradball(Imglist : Timagelist; arayon, pctspec : integer;
                          colball, collight, colmask, colspec : Tcolor);
var
  bmp : tbitmap;
  x, y : integer;       // colonnes lignes du bitmap
  rowa : Prgbarray;     // pointeur scanline
  cbx , cby : integer;  // centre de la boule
  Ray  : integer;       // rayon de la boule
  clx, cly : integer;   // position du point clair
  Rayl  : integer;      // rayon du dégradé autour du point clair
  rol : integer;        // distance au centre dégradé
  R, G, B    : integer;
  R1, G1, B1 : integer;
  R2, G2, B2 : integer;
  R3, G3, B3 : integer;
  R4, G4, B4 : integer;
  Rd, Gd, Bd : integer;
begin
  ray := arayon;
  if ray > imagelist1.width div 2 then ray := imagelist1.width div 2;
  if ray < 2  then ray := 2;
  if pctspec < 0   then pctspec := 0;
  if pctspec > 100 then pctspec := 100;
  try
    bmp := tbitmap.create;
    bmp.width :=  imagelist1.width;
    bmp.height := imagelist1.height;
    bmp.pixelformat := pf24bit;
    cbx := Bmp.width div 2;
    cby := Bmp.height div 2;
    clx  := cbx - ray div 3;
    cly  := cby - ray div 3;
    Rayl := ray*2;
    R1 := GetRValue(ColorToRGB(collight));    // couleur de départ
    G1 := GetGValue(ColorToRGB(collight));
    B1 := GetBValue(ColorToRGB(collight));
    R3 := GetRValue(ColorToRGB(colspec));      // couleur à mélanger
    G3 := GetGValue(ColorToRGB(colspec));
    B3 := GetBValue(ColorToRGB(colspec));
    R2 := GetRValue(ColorToRGB(colball));     // couleur de la balle
    G2 := GetGValue(ColorToRGB(colball));
    B2 := GetBValue(ColorToRGB(colball));

    R1 := (R1*(100-pctspec)+R3*pctspec) div 100;  // couleur lumière mélangée
    G1 := (G1*(100-pctspec)+G3*pctspec) div 100;
    B1 := (B1*(100-pctspec)+B3*pctspec) div 100;
    R2 := (R2*(100-pctspec)+R3*pctspec) div 100;  // couleur balle mélangée
    G2 := (G2*(100-pctspec)+G3*pctspec) div 100;
    B2 := (B2*(100-pctspec)+B3*pctspec) div 100;

    Rd := R2 - R1; // delta couleurs
    Gd := G2 - G1;
    Bd := B2 - B1;
    R4 := 255-GetRValue(ColorToRGB(colmask)); // couleur antimasque
    G4 := 255-GetGValue(ColorToRGB(colmask));
    B4 := 255-GetBValue(ColorToRGB(colmask));
    with bmp.canvas do   // dessin du masque et du cercle boule
    begin
      brush.color := colmask;
      fillrect(rect(0,0,bmp.width, bmp.height));
      brush.color := rgb(R4,G4,B4);             // couleur masque boule
      pen.color := brush.color;
      Ellipse(cbx-ray, cby-ray, cbx+ray, cby+ray);  // masque balle de couleur
    end;
    For y := 0 to bmp.height-1 do
    begin
      rowa := Bmp.scanline[y];
      for x := 0 to bmp.width-1 do
      begin
        R := rowa[x].Rgbtred;
        G := rowa[x].Rgbtgreen;
        B := rowa[x].Rgbtblue;
        if (R = R4) AND (G = G4) AND (B = B4) then  // si dans région balle
        begin
          rol := round(sqrt(sqr(clx-x)+sqr(cly-y)));
          if rol <= Rayl then
          begin
            R := (R1+(Rd*rol) div rayl) mod 256;
            G := (G1+(Gd*rol) div rayl) mod 256;
            B := (B1+(Bd*rol) div rayl) mod 256;
          end
          else
          begin
            R := R2;
            G := G2;
            B := B2;
          end;
        end;
        rowa[x].Rgbtred   := R;
        rowa[x].Rgbtgreen := G;
        rowa[x].Rgbtblue  := B;
      end;
    end;
    imglist.addmasked(bmp, colmask);
  finally
    bmp.free;
  end;
end;

procedure TForm1.PaintBox1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
   IF Button = mbRight then moving := 2 else moving := 1;
   prevx := x;
   prevy := y;
end;


procedure TForm1.PaintBox1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if moving = 0 then exit;
  IF moving = 1 Then
  begin
    Xang := Xang+(prevy-y) * (360 div paintbox1.width);
    Yang := Yang+(x-prevx) * (360 div paintbox1.height);
  end
  else Zang := Zang+(x+y-prevx-prevy) * (360 div paintbox1.height);
  prevx := x;
  prevy := y;
  paintbox1Paint(sender);
end;

procedure TForm1.PaintBox1MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  moving := 0;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  M : Matrix;                 // Matrice utilisée pour la rotation
  i, j, t, t2 : Integer;
  dx, dy : integer;
  affrect : Trect;             // union ancien et nouveau rectangle
begin
  matrixRotate(M, XAng , YAng, ZAng);   // crée la la matrice de rotation
  for i := 1 to  maxat do
  begin
    ApplyMatToPoint(Pts[i], PtsR[i], M);
    P2D[i] := Point(cx+round(PtsR[i].X), cy+round(PtsR[i].Y));
    // apparence de la boule selon éloignement
    Eloignement[i] :=  8 + (round(PtsR[i].Z) * 7) div rayon;
    ztri[i] := round(PtsR[i].z);      // valeur z pour tri
    priorite[i] := i;                 // le numéro atome pour tri
  end;
  for i:= Maxat downto 1 do           // tri selon éloignement (Z-order)
  for j := 1 to Maxat - 1 do
    if ztri[j] > ztri[j + 1] then
    begin
      T := ztri[j];
      t2 := priorite[j];
      ztri[J] := ztri[j + 1];
      priorite[j] := priorite[j+1];   // répercute le tri sur n° atome
      ztri[j + 1] := T;
      priorite[j+1] := t2;            // répercute le tri sur n° atome
    end;
  // effacement avec ancien rectangle
  Bmpmano.Canvas.copyrect(oldrect, Bmpfond.canvas, oldrect);
  // nouveau rectangle
  newrect := rect(cx-1, cy-1, cx+1, cy+1);
  For i := 1 to maxat do
  begin
    if P2D[i].x < newrect.left   then newrect.left   := P2D[i].x;
    if P2D[i].x > newrect.right  then newrect.right  := P2D[i].x;
    if P2D[i].y < newrect.top    then newrect.top    := P2D[i].y;
    if P2D[i].y > newrect.bottom then newrect.bottom := P2D[i].y;
  end;
  dx := imagelist1.width div 2;
  dy := imagelist1.height div 2;
  inflaterect(newrect, dx, dy);  // 1/2 dimension image
  // dessin des liaisons dans bmpmano
  IF checkbox1.checked then
  begin
    with bmpmano.canvas do
    begin
      pen.color := clbtnface;
      For i := 1 to maxliens do
      begin
        j := lien[i].x;    // n° atome départ
        Moveto(P2D[j].x,P2D[j].y);
        j := lien[i].y;    // n° atome destination
        Lineto(P2D[j].x,P2D[j].y);
      end;
    end;
  end;
  // dessin des atomes dans buffer bmpmano
  For i := maxat downto 1 do
  begin
    j := priorite[i];  // indirection pour afficher selon éloignement (z-order)
    case tat[j] of
    0: Imagelist1.draw(Bmpmano.canvas, P2D[j].x-dx,P2D[j].y-dy,eloignement[j]);
    1: Imagelist2.draw(Bmpmano.canvas, P2D[j].x-dx,P2D[j].y-dy,eloignement[j]);
    2: Imagelist3.draw(Bmpmano.canvas, P2D[j].x-dx,P2D[j].y-dy,eloignement[j]);
    3: Imagelist4.draw(Bmpmano.canvas, P2D[j].x-dx,P2D[j].y-dy,eloignement[j]);
    4: Imagelist5.draw(Bmpmano.canvas, P2D[j].x-dx,P2D[j].y-dy,eloignement[j]);
    end;
  end;
  // la zone modifiée de l'image concerne union ancien rectangle et nouveau
  unionrect(affrect, oldrect, newrect);
  Paintbox1.Canvas.copyrect(affrect, Bmpmano.canvas, affrect);
  oldrect := newrect;
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
  oldrect := rect(0,0,bmpmano.width, bmpmano.height); // effacement total
  paintbox1Paint(sender);
end;

end.
