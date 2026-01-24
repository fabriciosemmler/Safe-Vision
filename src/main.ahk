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
global ArquivoMemoria := A_ScriptDir . "\estado_tempo.ini"

; Tenta ler do arquivo. Se não existir, usa 20 e 2.
global MinutosTrabalho := IniRead(ArquivoMemoria, "Config", "Trabalho", 20)
global MinutosPausa    := IniRead(ArquivoMemoria, "Config", "Pausa", 2)

global X_Verde := A_ScreenWidth - 150
global Y_Verde := 30

; Valores Padrão
global SegundosRestantes := MinutosTrabalho * 60
global ModoAtual := "Trabalho" 

; Salva ao sair (Shutdown ou ExitApp)
OnExit(SalvarEstado)

; ==============================================================================
; CARREGAMENTO DA MEMÓRIA
; ==============================================================================
if FileExist(ArquivoMemoria) {
    try {
        SalvoSegundos := IniRead(ArquivoMemoria, "Estado", "Segundos", 0)
        SalvoModo     := IniRead(ArquivoMemoria, "Estado", "Modo", "Trabalho")
        SalvoTime     := IniRead(ArquivoMemoria, "Estado", "Timestamp", A_Now)

        ; Se os dados forem válidos
        if (SalvoTime != "" && IsNumber(SalvoSegundos)) {
            TempoDecorridoOff := DateDiff(A_Now, SalvoTime, "Seconds")
            
            SegundosRestantes := Integer(SalvoSegundos) - TempoDecorridoOff
            ModoAtual := SalvoModo

            if (SegundosRestantes <= 0) {
                SegundosRestantes := MinutosTrabalho * 60
                ModoAtual := "Trabalho"
            }
        }
    }
}

; Cálculo inicial do texto
TextoInicial := FormatarTempo(SegundosRestantes)

; ==============================================================================
; INTERFACE 1: RELÓGIO VERDE
; ==============================================================================
GuiVerde := Gui("+AlwaysOnTop -Caption +ToolWindow") 
GuiVerde.BackColor := "101010" 
GuiVerde.SetFont("s20 bold", "Segoe UI")
WinSetTransColor("101010", GuiVerde)

; 1. O RETÂNGULO "INVISÍVEL" (HITBOX)
FundoHitbox := GuiVerde.Add("Text", "x0 y0 w115 h45 Background121212")
FundoHitbox.OnEvent("Click", MostrarMenu)
FundoHitbox.OnEvent("ContextMenu", MostrarMenu)

; 2. O RELÓGIO (Camada da Frente)
TextoVerde := GuiVerde.Add("Text", "xp yp c00FF00 Right w80 BackgroundTrans", TextoInicial)
TextoVerde.OnEvent("Click", MostrarMenu)
TextoVerde.OnEvent("ContextMenu", MostrarMenu)

; 3. O MENU (≡)
TextoMenu := GuiVerde.Add("Text", "xp+80 yp c00FF00 Left w30 BackgroundTrans", "≡")
TextoMenu.OnEvent("Click", MostrarMenu)
TextoMenu.OnEvent("ContextMenu", MostrarMenu)

if (ModoAtual = "Trabalho")
    GuiVerde.Show("x" X_Verde " y" Y_Verde " w115 h45 NoActivate") 

; ==============================================================================
; INTERFACE 2: ALERTA VERMELHO
; ==============================================================================
GuiVermelho := Gui("+AlwaysOnTop -Caption +ToolWindow")
GuiVermelho.BackColor := "000000"
GuiVermelho.SetFont("s100 bold", "Segoe UI")
TextoVermelho := GuiVermelho.Add("Text", "x0 y200 cFF0000 Center w" A_ScreenWidth, TextoInicial)

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
    global SegundosRestantes, ModoAtual
    
    SegundosRestantes -= 1
    
    if (Mod(SegundosRestantes, 60) = 0)
        SalvarEstado()

    TempoFormatado := FormatarTempo(SegundosRestantes)
    
    if (ModoAtual = "Trabalho") {
        if (TextoVerde.Value != TempoFormatado)
            TextoVerde.Value := TempoFormatado

        ; Reforço do Verde
        try {
            GuiVerde.Opt("+AlwaysOnTop")
            WinMoveTop(GuiVerde.Hwnd)
        }
            
        if (SegundosRestantes <= 0)
            IniciarPausa()
    } 
    else {
        ; --- MODO PAUSA (Vermelho) ---
        if (TextoVermelho.Value != TempoFormatado)
            TextoVermelho.Value := TempoFormatado
            
        ; === CORREÇÃO AQUI ===
        ; Agora o Vermelho também briga pelo topo a cada segundo
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
    SegundosRestantes := MinutosPausa * 60
    SalvarEstado()
}

EncerrarPausa() {
    global SegundosRestantes, ModoAtual
    SoundBeep 1500, 300
    GuiVermelho.Hide()
    GuiVerde.Show("NoActivate")
    ModoAtual := "Trabalho"
    SegundosRestantes := MinutosTrabalho * 60
    SalvarEstado()
}

ReiniciarCiclo(*) {
    global SegundosRestantes, ModoAtual
    EncerrarPausa()
    MsgBox("Ciclo reiniciado!", "Safe Vision", "T3")
}

EncerrarApp(*) {
    SalvarEstado()
    ExitApp
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
    
    GuiConfig.Add("Text", "xm y+15", "☕ Pausa (minutos):")
    InputPausa := GuiConfig.Add("Edit", "w200 Number", MinutosPausa)
    
    BtnSalvar := GuiConfig.Add("Button", "xm y+20 w200 h40 Default", "Salvar e Aplicar")
    BtnSalvar.OnEvent("Click", SalvarPreferencias)
    
    GuiConfig.Show()

    SalvarPreferencias(*) {
        NovoTrab := InputTrab.Value
        NovoPausa := InputPausa.Value

        if (NovoTrab = "" || NovoPausa = "" || NovoTrab = 0 || NovoPausa = 0) {
            MsgBox("Por favor, insira valores válidos (maiores que 0).", "Erro", "Icon!")
            return
        }

        global MinutosTrabalho := Integer(NovoTrab)
        global MinutosPausa    := Integer(NovoPausa)

        IniWrite(MinutosTrabalho, ArquivoMemoria, "Config", "Trabalho")
        IniWrite(MinutosPausa,    ArquivoMemoria, "Config", "Pausa")

        GuiConfig.Destroy() 
        ReiniciarCiclo()    
    }
}

; ==============================================================================
; FUNÇÃO DE CLIQUE NO RELÓGIO
; ==============================================================================
MostrarMenu(*) {
    A_TrayMenu.Show() 
}