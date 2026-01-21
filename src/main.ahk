#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir 

; ==============================================================================
; MENU DA BANDEJA (TRAY ICON)
; ==============================================================================
A_IconTip := "Safe Vision - Gerenciador de Pausas"
A_TrayMenu.Delete()
A_TrayMenu.Add("Reiniciar Ciclo", ReiniciarCiclo)
A_TrayMenu.Add("Sair", EncerrarApp)

; ==============================================================================
; CONFIGURAÇÕES
; ==============================================================================
global MinutosTrabalho := 1
global MinutosPausa    := 1

global X_Verde := 1625
global Y_Verde := 30

global ArquivoMemoria := A_ScriptDir . "\estado_tempo.ini"

; Valores Padrão
global SegundosRestantes := MinutosTrabalho * 60
global ModoAtual := "Trabalho" 

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

; --- CÁLCULO IMEDIATO DO TEXTO (CORREÇÃO DO PULO) ---
; Formata o tempo AGORA, antes de criar a janela, para não aparecer "20:00" errado
MinIni := Format("{:02}", Floor(SegundosRestantes / 60))
SecIni := Format("{:02}", Mod(SegundosRestantes, 60))
TextoInicial := MinIni . ":" . SecIni
; ----------------------------------------------------

; ==============================================================================
; INTERFACE 1: RELÓGIO VERDE
; ==============================================================================
GuiVerde := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
GuiVerde.BackColor := "101010"
GuiVerde.SetFont("s20 bold", "Segoe UI")
WinSetTransColor("101010", GuiVerde)

; AQUI ESTÁ O TRUQUE: Usamos 'TextoInicial' em vez de "20:00" fixo
TextoVerde := GuiVerde.Add("Text", "c00FF00 Center w110", TextoInicial) 

if (ModoAtual = "Trabalho")
    GuiVerde.Show("x" X_Verde " y" Y_Verde " NoActivate")

; ==============================================================================
; INTERFACE 2: ALERTA VERMELHO
; ==============================================================================
GuiVermelho := Gui("+AlwaysOnTop -Caption +ToolWindow")
GuiVermelho.BackColor := "000000"

GuiVermelho.SetFont("s100 bold", "Segoe UI")
; Também usamos o TextoInicial aqui para prevenir glitch no modo pausa
TextoVermelho := GuiVermelho.Add("Text", "x0 y200 cFF0000 Center w" A_ScreenWidth, TextoInicial)

if (ModoAtual = "Pausa") {
    GuiVermelho.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NoActivate")
}

; ==============================================================================
; MOTOR DO TEMPO
; ==============================================================================
SetTimer CicloDeTempo, 1000

CicloDeTempo() {
    global SegundosRestantes, ModoAtual
    
    SegundosRestantes -= 1
    
    ; --- MELHORIA: Só salva a cada 60 segundos ou se estiver acabando ---
    ; Isso elimina o travamento de disco a cada segundo
    if (Mod(SegundosRestantes, 60) = 0)
        SalvarEstado()

    Min := Format("{:02}", Floor(SegundosRestantes / 60))
    Sec := Format("{:02}", Mod(SegundosRestantes, 60))
    TempoFormatado := Min . ":" . Sec
    
    if (ModoAtual = "Trabalho") {
        TextoVerde.Value := TempoFormatado
        if (SegundosRestantes <= 0)
            IniciarPausa()
    } 
    else {
        TextoVermelho.Value := TempoFormatado
        if (SegundosRestantes <= 0)
            EncerrarPausa()
    }
}

; ==============================================================================
; FUNÇÕES DE CONTROLE E ESTADO
; ==============================================================================

SalvarEstado(*) { ; O asterisco permite ser chamado pelo OnExit
    global SegundosRestantes, ModoAtual, ArquivoMemoria
    try {
        IniWrite SegundosRestantes, ArquivoMemoria, "Estado", "Segundos"
        IniWrite ModoAtual, ArquivoMemoria, "Estado", "Modo"
        IniWrite A_Now, ArquivoMemoria, "Estado", "Timestamp"
    }
}

IniciarPausa() {
    global SegundosRestantes, ModoAtual
    SoundBeep 1000, 1500 
    GuiVerde.Hide()
    GuiVermelho.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NoActivate")
    ModoAtual := "Pausa"
    SegundosRestantes := MinutosPausa * 60
    SalvarEstado()
}

EncerrarPausa() {
    global SegundosRestantes, ModoAtual
    Loop 3 {
        SoundBeep 1500, 200
        Sleep 100
    }
    GuiVermelho.Hide()
    GuiVerde.Show("NoActivate")
    ModoAtual := "Trabalho"
    SegundosRestantes := MinutosTrabalho * 60
    SalvarEstado()
}

ReiniciarCiclo(*) {
    global SegundosRestantes, ModoAtual
    EncerrarPausa()
    SegundosRestantes := MinutosTrabalho * 60
    ModoAtual := "Trabalho"
    SalvarEstado()
    MsgBox("Ciclo reiniciado!", "Safe Vision", "T3")
}

EncerrarApp(*) {
    SalvarEstado()
    ExitApp
}