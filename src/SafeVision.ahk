#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir 

; ==============================================================================
; OTIMIZAÇÃO DE PERFORMANCE
; ==============================================================================
SetWinDelay -1      
SetControlDelay -1  

; ==============================================================================
; MENU DA BANDEJA (TRAY ICON)
; ==============================================================================
A_IconTip := "Safe Vision - Gerenciador de Pausas"
A_TrayMenu.Delete()
A_TrayMenu.Add("⚙️ Configurações", AbrirConfiguracoes)
A_TrayMenu.Add("Reiniciar Ciclo", ReiniciarCiclo)
A_TrayMenu.Add("Sair", EncerrarApp)

; ==============================================================================
; CONFIGURAÇÕES
; ==============================================================================

PastaDados := A_AppData . "\SafeVision"
if !DirExist(PastaDados)
    DirCreate(PastaDados)

global ArquivoMemoria := PastaDados . "\estado_tempo.ini"

global MinutosTrabalho := IniRead(ArquivoMemoria, "Config", "Trabalho", 20)
global MinutosPausa    := IniRead(ArquivoMemoria, "Config", "Pausa", 2)

global X_Verde := A_ScreenWidth - 150
global Y_Verde := 30

; Valores Padrão
global SegundosRestantes := MinutosTrabalho * 60
global ModoAtual := "Trabalho" 
global JanelaFocadaAoTerminar := 0 
global TituloFocadoAoTerminar := ""

OnExit(SalvarEstado)

; ==============================================================================
; CARREGAMENTO DA MEMÓRIA
; ==============================================================================
CarregarMemoria := false

if FileExist(ArquivoMemoria) {
    TempoLigadoSegundos := A_TickCount // 1000
    DataHoraBoot := DateAdd(A_Now, -TempoLigadoSegundos, "Seconds")
    DataHoraUltimoSave := FileGetTime(ArquivoMemoria)

    if (DateDiff(DataHoraBoot, DataHoraUltimoSave, "Seconds") < 0) {
        CarregarMemoria := true
    }
}

if (CarregarMemoria) {
    try {
        SalvoSegundos := IniRead(ArquivoMemoria, "Estado", "Segundos", 0)
        SalvoModo     := IniRead(ArquivoMemoria, "Estado", "Modo", "Trabalho")
        SalvoTime     := IniRead(ArquivoMemoria, "Estado", "Timestamp", A_Now)

        if (SalvoTime != "" && IsNumber(SalvoSegundos)) {
            TempoDecorridoOff := DateDiff(A_Now, SalvoTime, "Seconds")
            SegundosRestantes := Integer(SalvoSegundos) - TempoDecorridoOff
            ModoAtual := SalvoModo

            if (SegundosRestantes <= 0 && ModoAtual == "Trabalho") {
                SegundosRestantes := MinutosTrabalho * 60
                ModoAtual := "Trabalho"
            }
        }
    }
}

TextoInicial := FormatarTempo(SegundosRestantes)

; ==============================================================================
; INTERFACE 1: RELÓGIO VERDE
; ==============================================================================
GuiVerde := Gui("+AlwaysOnTop -Caption +ToolWindow") 
GuiVerde.BackColor := "101010" 
GuiVerde.SetFont("s20 bold", "Segoe UI")
WinSetTransColor("101010", GuiVerde)

FundoHitbox := GuiVerde.Add("Text", "x0 y0 w115 h45 Background121212")
FundoHitbox.OnEvent("Click", MostrarMenu)
FundoHitbox.OnEvent("ContextMenu", MostrarMenu)

TextoVerde := GuiVerde.Add("Text", "xp yp c00FF00 Right w80 BackgroundTrans", TextoInicial)
TextoVerde.OnEvent("Click", MostrarMenu)
TextoVerde.OnEvent("ContextMenu", MostrarMenu)

TextoMenu := GuiVerde.Add("Text", "xp+80 yp c00FF00 Left w30 BackgroundTrans", "≡")
TextoMenu.OnEvent("Click", MostrarMenu)
TextoMenu.OnEvent("ContextMenu", MostrarMenu)

if (ModoAtual = "Trabalho")
    GuiVerde.Show("x" X_Verde " y" Y_Verde " w115 h45 NoActivate") 

; ==============================================================================
; INTERFACE 2: ALERTA VERMELHO (ATUALIZADA)
; ==============================================================================
GuiVermelho := Gui("+AlwaysOnTop -Caption +ToolWindow")
GuiVermelho.BackColor := "000000"

; Relógio Gigante
GuiVermelho.SetFont("s100 bold", "Segoe UI")
TextoVermelho := GuiVermelho.Add("Text", "x0 y200 cFF0000 Center w" A_ScreenWidth, TextoInicial)

; --- NOVO: BOTÃO DISCRETO DE PÂNICO ---
GuiVermelho.SetFont("s12 norm", "Segoe UI")
; Cor c330000 é um vermelho bem escuro, quase marrom, para não chamar atenção
BtnPular := GuiVermelho.Add("Text", "x" (A_ScreenWidth - 150) " y" (A_ScreenHeight - 50) " w130 h30 c330000 Right", "Pular Pausa ⏭")
BtnPular.OnEvent("Click", PularPausaManual)
; --------------------------------------

if (ModoAtual = "Pausa") {
    GuiVermelho.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NoActivate")
} else {
    GuiVermelho.Hide() 
}

; ==============================================================================
; MOTOR DO TEMPO
; ==============================================================================
SetTimer CicloDeTempo, 1000

CicloDeTempo() {
    global SegundosRestantes, ModoAtual, JanelaFocadaAoTerminar, TituloFocadoAoTerminar
    static UltimaExecucao := A_Now

    if (DateDiff(A_Now, UltimaExecucao, "Seconds") > 10) {
        ReiniciarCiclo() 
        UltimaExecucao := A_Now
    }
    UltimaExecucao := A_Now
    
    if (ModoAtual == "Espera") {
        try {
            JanelaAtual := WinGetID("A")
            TituloAtual := WinGetTitle("A")
        } catch {
            JanelaAtual := 0
            TituloAtual := ""
        }
        
        if (JanelaAtual != JanelaFocadaAoTerminar || TituloAtual != TituloFocadoAoTerminar) {
            IniciarPausa()
        }
        
        CorAlerta := (Mod(A_TickCount, 2000) < 1000) ? "cFFAA00" : "cFF0000"
        TextoVerde.Opt(CorAlerta)
        TextoVerde.Value := "00:00"
        return 
    }

    SegundosRestantes -= 1
    
    if (Mod(SegundosRestantes, 60) = 0)
        SalvarEstado()

    TempoFormatado := FormatarTempo(SegundosRestantes)
    
    if (ModoAtual = "Trabalho") {
        if (TextoVerde.Value != TempoFormatado) {
            TextoVerde.Value := TempoFormatado
            TextoVerde.Opt("c00FF00")
        }

        try {
            GuiVerde.Opt("+AlwaysOnTop")
            WinMoveTop(GuiVerde.Hwnd)
        }
            
        if (SegundosRestantes <= 0) {
            ModoAtual := "Espera"
            try {
                JanelaFocadaAoTerminar := WinGetID("A")
                TituloFocadoAoTerminar := WinGetTitle("A")
            } catch {
                JanelaFocadaAoTerminar := 0
                TituloFocadoAoTerminar := ""
            }
            SoundBeep 750, 150 
        }
    } 
    else { 
        if (TextoVermelho.Value != TempoFormatado)
            TextoVermelho.Value := TempoFormatado
            
        try {
            GuiVermelho.Opt("+AlwaysOnTop")
            WinMoveTop(GuiVermelho.Hwnd)
        }
            
        if (SegundosRestantes <= 0)
            EncerrarPausa()
    }
}

; ==============================================================================
; FUNÇÕES AUXILIARES
; ==============================================================================
FormatarTempo(seg) {
    return Format("{:02}:{:02}", Floor(seg / 60), Mod(seg, 60))
}

SalvarEstado(*) {
    global SegundosRestantes, ModoAtual, ArquivoMemoria
    try {
        IniWrite SegundosRestantes, ArquivoMemoria, "Estado", "Segundos"
        IniWrite ModoAtual, ArquivoMemoria, "Estado", "Modo"
        IniWrite A_Now, ArquivoMemoria, "Estado", "Timestamp"
    }
}

IniciarPausa() {
    global SegundosRestantes, ModoAtual
    SalvarEstado()
    SoundBeep 1000, 500 
    GuiVerde.Hide()
    GuiVermelho.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NoActivate")
    ModoAtual := "Pausa"
    SegundosRestantes := ConverterTempoPausa(MinutosPausa)
    SalvarEstado()
}

EncerrarPausa() {
    global SegundosRestantes, ModoAtual
    SoundBeep 1500, 300
    GuiVermelho.Hide()
    GuiVerde.Show("NoActivate")
    TextoVerde.Opt("c00FF00")
    ModoAtual := "Trabalho"
    SegundosRestantes := MinutosTrabalho * 60
    SalvarEstado()
}

; Função wrapper para o botão (poderia adicionar log de "trapaça" aqui no futuro)
PularPausaManual(*) {
    EncerrarPausa()
}

ReiniciarCiclo(*) {
    global SegundosRestantes, ModoAtual
    EncerrarPausa()
    TextoVerde.Opt("c00FF00")
}

EncerrarApp(*) {
    SalvarEstado()
    ExitApp
}

ConverterTempoPausa(texto) {
    if InStr(texto, ":") {
        partes := StrSplit(texto, ":")
        return (Integer(partes[1]) * 60) + Integer(partes[2])
    }
    return Integer(texto)
}

; ==============================================================================
; TELA DE CONFIGURAÇÕES
; ==============================================================================
AbrirConfiguracoes(*) {
    GuiConfig := Gui("+AlwaysOnTop", "Safe Vision Config")
    GuiConfig.SetFont("s10", "Segoe UI")
    GuiConfig.BackColor := "White"
    
    GuiConfig.Add("Text", "xm", "⏱️ Trabalho (minutos):")
    InputTrab := GuiConfig.Add("Edit", "w200 Number", MinutosTrabalho)
    
    GuiConfig.Add("Text", "xm y+15", "☕ Pausa (MM:SS ou Segundos):")
    InputPausa := GuiConfig.Add("Edit", "w200", MinutosPausa)
    
    BtnSalvar := GuiConfig.Add("Button", "xm y+20 w200 h40 Default", "Salvar e Aplicar")
    BtnSalvar.OnEvent("Click", SalvarPreferencias)
    
    GuiConfig.Show()

    SalvarPreferencias(*) {
        NovoTrab := InputTrab.Value
        NovoPausa := InputPausa.Value

        if (NovoTrab = "" || NovoPausa = "") {
            MsgBox("Por favor, preencha todos os campos.", "Erro", "Icon!")
            return
        }

        global MinutosTrabalho := Integer(NovoTrab)
        global MinutosPausa    := NovoPausa

        IniWrite(MinutosTrabalho, ArquivoMemoria, "Config", "Trabalho")
        IniWrite(MinutosPausa,    ArquivoMemoria, "Config", "Pausa")

        GuiConfig.Destroy() 
        ReiniciarCiclo()    
    }
}

MostrarMenu(*) {
    A_TrayMenu.Show() 
}