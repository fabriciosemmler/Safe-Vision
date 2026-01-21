#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir 

; ==============================================================================
; OTIMIZAÇÃO DE PERFORMANCE (A Correção do Lag)
; ==============================================================================
SetWinDelay -1      ; Remove delays de manipulação de janela
SetControlDelay -1  ; Remove delays de controle

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
; global MinutosTrabalho := 20
; global MinutosPausa    := 2

; Tenta ler do arquivo. Se não existir, usa 20 e 2.
global MinutosTrabalho := IniRead(ArquivoMemoria, "Config", "Trabalho", 20)
global MinutosPausa    := IniRead(ArquivoMemoria, "Config", "Pausa", 2)

global X_Verde := A_ScreenWidth - 150
global Y_Verde := 30

global ArquivoMemoria := A_ScriptDir . "\estado_tempo.ini"

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
; INTERFACE 1: RELÓGIO VERDE (Agora Clicável)
; ==============================================================================
; REMOVI O "+E0x20" para que o mouse possa clicar na janela
GuiVerde := Gui("+AlwaysOnTop -Caption +ToolWindow") 
GuiVerde.BackColor := "101010"
GuiVerde.SetFont("s20 bold", "Segoe UI")
WinSetTransColor("101010", GuiVerde)

; Texto 1: O Relógio (Alinhado à direita para ficar colado no menu)
TextoVerde := GuiVerde.Add("Text", "c00FF00 Right w80", TextoInicial)
TextoVerde.OnEvent("Click", MostrarMenu) ; Ao clicar, chama a função do menu

; Texto 2: O Símbolo de Menu (Alinhado à esquerda, logo após o relógio)
; "xp+80" significa: pegue a posição X anterior e some 80 pixels
; "yp" significa: use a mesma altura Y (mesma linha)
TextoMenu := GuiVerde.Add("Text", "xp+80 yp c00FF00 Left w30", "≡")
TextoMenu.OnEvent("Click", MostrarMenu)

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
} else {
    GuiVermelho.Hide() ; Garante que a janela fullscreen não fique "assombrando" o mouse
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
        ; OTIMIZAÇÃO: Só atualiza o controle se o texto mudou (evita repintura desnecessária)
        if (TextoVerde.Value != TempoFormatado)
            TextoVerde.Value := TempoFormatado
            
        if (SegundosRestantes <= 0)
            IniciarPausa()
    } 
    else {
        if (TextoVermelho.Value != TempoFormatado)
            TextoVermelho.Value := TempoFormatado
            
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
    SoundBeep 1000, 500 ; Beep mais curto para não travar
    GuiVerde.Hide()
    GuiVermelho.Show("x0 y0 w" A_ScreenWidth " h" A_ScreenHeight " NoActivate")
    ModoAtual := "Pausa"
    SegundosRestantes := MinutosPausa * 60
    SalvarEstado()
}

EncerrarPausa() {
    global SegundosRestantes, ModoAtual
    ; Removido loop de beeps que podia causar atraso
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
    
    ; Campo Trabalho
    GuiConfig.Add("Text", "xm", "⏱️ Trabalho (minutos):")
    InputTrab := GuiConfig.Add("Edit", "w200 Number", MinutosTrabalho)
    
    ; Campo Pausa
    GuiConfig.Add("Text", "xm y+15", "☕ Pausa (minutos):")
    InputPausa := GuiConfig.Add("Edit", "w200 Number", MinutosPausa)
    
    ; Botão Salvar
    BtnSalvar := GuiConfig.Add("Button", "xm y+20 w200 h40 Default", "Salvar e Aplicar")
    BtnSalvar.OnEvent("Click", SalvarPreferencias)
    
    GuiConfig.Show()

    ; Função interna para processar o clique
    SalvarPreferencias(*) {
        NovoTrab := InputTrab.Value
        NovoPausa := InputPausa.Value

        if (NovoTrab = "" || NovoPausa = "" || NovoTrab = 0 || NovoPausa = 0) {
            MsgBox("Por favor, insira valores válidos (maiores que 0).", "Erro", "Icon!")
            return
        }

        ; Atualiza as variáveis globais
        global MinutosTrabalho := Integer(NovoTrab)
        global MinutosPausa    := Integer(NovoPausa)

        ; Salva no arquivo INI
        IniWrite(MinutosTrabalho, ArquivoMemoria, "Config", "Trabalho")
        IniWrite(MinutosPausa,    ArquivoMemoria, "Config", "Pausa")

        ; --- A MUDANÇA ESTÁ AQUI ---
        GuiConfig.Destroy() ; 1º: Fecha a janela IMEDIATAMENTE (sem esperar nada)
        
        ; Removi a MsgBox("Configurações salvas!") porque era redundante.
        ; O ReiniciarCiclo já vai mostrar que deu tudo certo.
        
        ReiniciarCiclo()    ; 2º: Inicia o novo ciclo (que mostrará sua própria MsgBox limpa)
    }

}

; ==============================================================================
; FUNÇÃO DE CLIQUE NO RELÓGIO
; ==============================================================================
MostrarMenu(*) {
    A_TrayMenu.Show() ; Exibe o menu da bandeja na posição do mouse
}