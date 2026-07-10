# Guia de Adaptação de Código para Xbox (Mega Man X8 16-bit) — v2

**Atualizado após inspeção real do código-fonte do projeto** (repositório `AlyssonDaPaz/Mega-Man-X8-16-bit`, branch `main`, Godot Engine 3.5). Este documento substitui a v1 genérica e reflete o estado de fato do projeto.

## 0. Resumo do que foi encontrado (diagnóstico)

| Item | Estado encontrado | Ação necessária |
| :--- | :--- | :--- |
| Engine | Godot **3.5** (não "3.x" genérico) | Confirmar export templates 3.5 ao instalar |
| Resolução base | `398x224`, `stretch=2d`, `aspect=keep` | Nenhuma — já adequado para 16:9 |
| C# no projeto | Só no plugin de editor `godot_tiled_importer` (Tiled importer) | Nenhuma — não roda em runtime, não precisa de build Mono |
| InputMap | Já mapeado para padrão Xbox (A=jump, B=dash, X=fire, Y=alt_fire, LB/RB=troca de arma, Start=pause, D-Pad=movimento) | Nenhuma mudança de binding — só validar XInput em UWP de fato |
| Save (`user://`) | Usa caminho virtual do Godot, compatível com sandboxing do UWP | Nenhuma |
| Opção "Fullscreen" no menu | Chamava `OS.window_fullscreen` diretamente | **Corrigido**: oculta a linha inteira do menu quando `Tools.is_console_platform()` |
| Opção "Window Size" (multiplicador 1x-10x) | Chamava `OS.set_window_size` | **Corrigido**: mesmo tratamento de ocultação |
| Opção "Vsync" | Não depende de modo de janela | Mantida como está — vsync é válido em UWP/Xbox |
| Preset de export UWP | **Não existia** no `export_presets.cfg` | **Criado**: preset `"UWP Xbox Series S"` |

## 1. Input: o que já está certo e o que falta validar

Diferente do que um guia genérico assumiria, o `InputMap` deste projeto **já usa os `button_index` corretos para um controle Xbox padrão** (a numeração do Godot 3.x para joystick segue a SDL game controller database, que já é consistente com XInput):

| Ação (`InputMap`) | button_index | Botão Xbox |
| :--- | :--- | :--- |
| `jump` | 0 | A |
| `dash` | 1 | B |
| `fire` | 2 | X |
| `alt_fire` | 3 | Y |
| `weapon_select_left` | 4 | LB |
| `weapon_select_right` | 5 | RB |
| `reset_weapon` | 9 | Stick direito (clique) |
| `debug` | 11 | Start/Menu (em build de debug) |
| `pause` | 11 | Start/Menu |
| `move_up/down/left/right` | 12/13/14/15 | D-Pad |
| `analog_left/right/up/down` | eixo 2/3 | Stick direito (usado para o cursor de seleção de arma) |

**Não recomendamos alterar esses bindings.** O risco real não está no mapeamento lógico, e sim em como o **runtime UWP do Godot 3.5** lê o XInput do Xbox Series S — esse é o tipo de bug que só aparece testando no console e não tem solução de código antecipada. Ao testar:

- Confirme que o stick esquerdo move o personagem (eixo 0/1 — não vimos esse binding explicitamente nas ações `move_*`, que usam D-Pad; se quiser stick esquerdo para movimento, será necessário adicionar esse binding manualmente no `InputMap` do Godot).
- Confirme que os gatilhos (LT/RT) não geram nenhum input fantasma — controles Xbox no Windows/UWP às vezes reportam o eixo do gatilho mesmo sem o usuário tocar.

### 1.1. Sistema de remapeamento de tecla (KeyBinder)

O projeto tem uma tela de opções dedicada para o jogador remapear teclas e botões (`src/Options/KeyBinder/`). Ela já distingue `InputEventJoypadButton`/`InputEventJoypadMotion` de `InputEventKey`/`InputEventMouseButton` (ver `MapInput.gd` e `ActionInput.gd`). Isso significa que a tela de rebind **deve continuar funcionando com um controle Xbox sem mudanças de código**, mas dois pontos pedem atenção/teste manual no console:

- Confirme que é possível **cancelar** uma operação de rebind sem precisar de teclado (o código tem um timeout de 5s automático em `MapInput._process`, que ajuda, mas vale confirmar na prática).
- A coluna "key" (teclado) da tela de rebind exibirá controles que não existem no Xbox. Avalie se vale esconder essa coluna em build console — não fizemos essa alteração porque é uma decisão de design/UX, não uma correção técnica obrigatória.

## 2. Opções de janela ocultadas em build UWP/Xbox

Adicionamos um helper centralizado em `Tools.gd`:

```gdscript
static func is_uwp_platform() -> bool:
    return OS.has_feature("UWP") or OS.get_name() == "UWP"

static func is_console_platform() -> bool:
    return is_uwp_platform()
```

> **Atenção**: usamos `OS.has_feature("UWP")` como verificação primária porque é o mecanismo documentado e oficial do Godot 3.x para detectar a plataforma de export em runtime (feature tags). Adicionamos `OS.get_name() == "UWP"` como fallback redundante. **Isso precisa ser validado rodando de fato em um build UWP** (editor com export ativo ou no próprio Xbox) — não tínhamos como confirmar 100% sem executar o motor.

Com esse helper, dois itens do menu de opções agora se autodesativam em build UWP:

- **`src/Options/Fullscreen.gd`**: a linha inteira do menu (`Control` pai do botão) fica `visible = false` e sai do foco (`focus_mode = Control.FOCUS_NONE`). Containers do Godot ignoram filhos invisíveis no cálculo de layout, então a lista de opções se reorganiza automaticamente sem buraco.
- **`src/Options/Size.gd`** (multiplicador de tamanho de janela 1x–10x): mesmo tratamento, pelo mesmo motivo — no Xbox a janela é sempre gerenciada em tela cheia pelo shell do sistema, então essa opção não tem efeito útil.

**`src/Options/Vsync.gd` não foi alterado** — vsync é um conceito válido independente do modo de janela, então continua disponível no Xbox.

## 3. Ajustes de Resolução e Aspect Ratio

A configuração de display do projeto **já está correta** e não precisa de mudança:

- `window/stretch/mode = "2d"` — mantém o aspecto pixel art sem distorção.
- `window/stretch/aspect = "keep"` — preserva proporção com letterboxing se necessário.
- Resolução base `398x224` já é praticamente 16:9 (proporção ≈1.777), então o letterboxing em uma TV moderna deve ser mínimo ou inexistente.

## 4. Otimização de Performance

O projeto é leve (2D, sprites pixel art), mas o runtime UWP do Godot 3.5 tem bugs de estabilidade conhecidos e independentes do seu código (ver guia de build, seção "Problemas conhecidos do exportador UWP"). Não há ação de código a fazer aqui além do que já existe — `run/low_processor_mode=true` já está habilitado no `project.godot`, o que é positivo para um console com recursos mais limitados que um PC.

## 5. Integração com Serviços do Xbox (Opcional)

Não implementado nesta fase. Caso queira adicionar achievements/leaderboards do Xbox Live, o plugin GDNative [`GodotXbox`](https://github.com/CreggHancock/GodotXbox) é o ponto de partida documentado pela comunidade para Godot 3.x, mas exige cadastro do jogo no Xbox Partner Center (fora do escopo de Dev Mode/sideload puro).
